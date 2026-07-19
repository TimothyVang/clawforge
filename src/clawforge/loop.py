"""The heartbeat — the core Claw Agent loop.

Wakes on an interval (time-triggered, not prompt-triggered), senses, reasons,
acts, persists, and either sleeps or exits. Model failures are caught and become
a recovery event (log + retry next cycle) rather than a crash.
"""
from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timezone
from typing import Any

from . import act, board, briefing, decide, discord, dispatch, sense, tasks, todos
from .client import ModelClient, ModelError
from .config import Config, CONFIG
from .ledger import Ledger


def _reconcile_done(state, ledger, config) -> list[dict]:
    """Closed issues that clawforge previously put on the board -> Done column."""
    out: list[dict] = []
    for repo, closed in sense.watched_closed_groups(state):
        for it in closed:
            num = it["number"]
            if not ledger.has_acted(f"board-todo:{repo}#{num}"):
                continue  # only issues we tracked
            done_key = f"board-done:{repo}#{num}"
            if ledger.has_acted(done_key):
                continue
            b = board.move(board.issue_url(repo, num), "Done", config)
            ledger.record(done_key, b)
            discord.post_to("done", f"✅ **Done** — {repo}#{num}: {it['title']}", config)
            out.append({"number": num, "repo": repo, "board": b})
    return out


def _maybe_dispatch(client, state, decision, ledger, config) -> list[dict]:
    """Dispatch at most one ready work-repo issue per cycle to a coder -> PR.

    Targets any work-repo issue labeled `triage/ready` (whether triaged this cycle
    or earlier) that hasn't been dispatched yet — guarded by the ledger.
    """
    if not config.dispatch_enabled:
        return []
    out: list[dict] = []
    for issue in state.get("work_issues", []):
        if "triage/ready" not in sense.label_names(issue):
            continue
        key = f"dispatch:{state['work_repo']}#{issue['number']}"
        if ledger.has_acted(key):
            continue
        try:
            r = dispatch.dispatch_issue(client, issue, state["work_repo"], config)
            ledger.record(key, r["pr"])
            # PR opened -> advance the board card to In Progress.
            b = board.move(board.issue_url(state["work_repo"], issue["number"]),
                           "In Progress", config)
            out.append({"number": issue["number"], "status": "PR", "board": b, **r})
        except Exception as exc:  # noqa: BLE001
            ledger.record(key, f"failed:{str(exc)[:80]}")
            out.append({"number": issue["number"], "status": f"failed: {str(exc)[:120]}"})
        break  # one PR per cycle
    return out


def _ts() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _log(config: Config, line: str) -> None:
    config.ensure_dirs()
    with open(config.log_path, "a") as f:
        f.write(f"{_ts()} {line}\n")
    # In JSON mode, keep stdout pure JSON by routing human logs to stderr.
    stream = sys.stderr if config.json_output else sys.stdout
    print(f"[clawforge {_ts()}] {line}", file=stream, flush=True)


def _cycle_record(cycle: int, state, decision, result, error=None) -> dict[str, Any]:
    """Structured, machine-readable summary of one cycle (the JSON snapshot)."""
    rec: dict[str, Any] = {
        "cycle": cycle,
        "timestamp": _ts(),
        "error": error,
    }
    if state:
        rec["repo"] = state["repo"]
        rec["work_repo"] = state["work_repo"]
        rec["counts"] = state["counts"]
    if decision:
        rec["standup"] = decision.get("standup", "")
        rec["untriaged"] = decision.get("untriaged")
        rec["latency_s"] = decision.get("latency_s")
        rec["actions"] = decision.get("actions", [])
    if result:
        rec["applied"] = result.get("applied", [])
        rec["dispatched"] = result.get("dispatched", [])
        rec["done"] = result.get("done", [])
        rec["ready"] = result.get("ready")
        rec["discord"] = result.get("status_post")
    return rec


def _write_json_snapshot(config: Config, record: dict[str, Any]) -> None:
    """Persist the structured cycle record; echo to stdout in --json mode."""
    config.ensure_dirs()
    payload = json.dumps(record, indent=2, sort_keys=True)
    config.json_snapshot_path.write_text(payload + "\n")
    if config.json_output:
        # One JSON object per cycle on stdout (JSON Lines when run continuously).
        print(json.dumps(record, sort_keys=True), flush=True)


def _snapshot(config: Config, cycle: int, state, decision, result, error=None) -> None:
    md = [f"# Clawforge cycle {cycle} — {_ts()}", ""]
    if error:
        md.append(f"**FAILURE (recovering next cycle):** {error}\n")
    if state:
        c = state["counts"]
        watched = ", ".join(w["repo"] for w in state.get("watched", [{"repo": state["repo"]}]))
        md.append(f"- watched **{watched}** | work **{state['work_repo']}**")
        md.append(f"- open issues: {c['issues']} | work issues: {c['work_issues']} | PRs: {c['prs']}")
    md.append("\n## Standup\n" + (decision.get("standup", "") if decision else "_(none)_"))
    md.append("\n## Decisions")
    for a in (decision.get("actions", []) if decision else []):
        md.append(f"- {a['repo']}#{a['number']} → `{a['label']}` (ready={a['ready']}) — {a['rationale']}")
    if decision and decision.get("reasoning"):
        md += ["\n## Model reasoning trace", "```", decision["reasoning"][:1500], "```"]
    if result:
        md.append("\n## Applied")
        md += [
            f"- {x['repo']}#{x['number']}: {x['status']}"
            + (f" · board {x['board']}" if x.get("board") else "")
            for x in result["applied"]
        ]
        md.append(f"- discord: {result['discord']}")
        for d in result.get("dispatched", []):
            if d["status"] == "PR":
                md.append(f"- dispatched #{d['number']} → PR {d['pr']} (`{d['path']}`)")
            else:
                md.append(f"- dispatched #{d['number']}: {d['status']}")
    config.snapshot_path.write_text("\n".join(md) + "\n")


def run_cycle(client: ModelClient, ledger: Ledger, config: Config = CONFIG) -> bool:
    cycle = ledger.bump_cycle()
    try:
        state = sense.read_state(config)
        decision = decide.decide(client, state)
        result = act.apply(decision, ledger, config)
        result["dispatched"] = _maybe_dispatch(client, state, decision, ledger, config)
        result["done"] = _reconcile_done(state, ledger, config)
        # Next-task agent prompts (file + Discord).
        ready = tasks.next_tasks(state)
        (config.state_dir / "next-tasks.md").write_text(tasks.render_md(ready, state))
        result["ready"] = len(ready)
        # Post each newly-ready task to #next-tasks exactly once.
        for t in ready:
            tkey = f"dc-task:{t['repo']}#{t['number']}"
            if not ledger.has_acted(tkey):
                discord.post_to(
                    "next-tasks",
                    f"📋 **Task ready** — {t['repo']}#{t['number']}\n```\n{t['prompt']}\n```",
                    config)
                ledger.record(tkey, "posted")
        # PM briefing to #status: on activity, or a periodic heartbeat (~30 min)
        # so the board stays visible even on a quiet cycle. Built only when posting
        # (each build is a couple of gh calls) to keep idle cycles cheap.
        activity = len(result["applied"]) + len(result["dispatched"]) + len(result["done"])
        if activity or cycle % 30 == 0:
            tracked = {w["repo"] for w in state.get("watched", [])} | {state["work_repo"]}
            board_items = board.list_items(config, repos=tracked)
            milestones = sense.read_milestones(sorted(tracked))
            todo_map = todos.generate_for_projects(client, state)
            brief = briefing.pm_briefing(state, result, board_items, milestones, todo_map)
            (config.state_dir / "board-status.md").write_text(brief)
            result["status_post"] = discord.post_to("status", brief, config)
        else:
            result["status_post"] = "no-activity"
        ledger.save()
        _snapshot(config, cycle, state, decision, result)
        _write_json_snapshot(config, _cycle_record(cycle, state, decision, result))
        _log(config,
             f"cycle {cycle}: untriaged={decision['untriaged']} "
             f"applied={len(result['applied'])} dispatched={len(result['dispatched'])} "
             f"done={len(result['done'])} ready={result['ready']} "
             f"latency={decision['latency_s']}s discord={result['status_post']}")
        return True
    except ModelError as exc:
        ledger.save()
        _snapshot(config, cycle, None, None, None, error=str(exc))
        _write_json_snapshot(config, _cycle_record(cycle, None, None, None, error=str(exc)))
        _log(config, f"cycle {cycle}: MODEL FAILURE (recovering): {exc}")
        return False
    except Exception as exc:  # noqa: BLE001 — never let the heartbeat die
        ledger.save()
        _log(config, f"cycle {cycle}: ERROR: {exc}")
        return False


def run(config: Config = CONFIG, once: bool = False) -> None:
    config.ensure_dirs()
    client = ModelClient(config)
    _log(config,
         f"start model={config.model} base_url={config.base_url} "
         f"interval={config.interval_seconds}s dry_run={config.dry_run}")
    _log(config, f"warmup: {'ok' if client.warmup() else 'endpoint down (retrying in loop)'}")

    ledger = Ledger(config)
    n = 0
    while True:
        run_cycle(client, ledger, config)
        n += 1
        if once or (config.max_cycles and n >= config.max_cycles):
            break
        time.sleep(config.interval_seconds)
    _log(config, f"stopped after {n} cycle(s); lifetime cycles={ledger.cycles}")
