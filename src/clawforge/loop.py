"""The heartbeat — the core Claw Agent loop.

Wakes on an interval (time-triggered, not prompt-triggered), senses, reasons,
acts, persists, and either sleeps or exits. Model failures are caught and become
a recovery event (log + retry next cycle) rather than a crash.
"""
from __future__ import annotations

import time
from datetime import datetime, timezone
from typing import Any

from . import act, decide, dispatch, sense
from .client import ModelClient, ModelError
from .config import Config, CONFIG
from .ledger import Ledger


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
            out.append({"number": issue["number"], "status": "PR", **r})
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
    print(f"[clawforge {_ts()}] {line}", flush=True)


def _snapshot(config: Config, cycle: int, state, decision, result, error=None) -> None:
    md = [f"# Clawforge cycle {cycle} — {_ts()}", ""]
    if error:
        md.append(f"**FAILURE (recovering next cycle):** {error}\n")
    if state:
        c = state["counts"]
        md.append(f"- watched **{state['repo']}** | work **{state['work_repo']}**")
        md.append(f"- open issues: {c['issues']} | work issues: {c['work_issues']} | PRs: {c['prs']}")
    md.append("\n## Standup\n" + (decision.get("standup", "") if decision else "_(none)_"))
    md.append("\n## Decisions")
    for a in (decision.get("actions", []) if decision else []):
        md.append(f"- {a['repo']}#{a['number']} → `{a['label']}` (ready={a['ready']}) — {a['rationale']}")
    if decision and decision.get("reasoning"):
        md += ["\n## Model reasoning trace", "```", decision["reasoning"][:1500], "```"]
    if result:
        md.append("\n## Applied")
        md += [f"- {x['repo']}#{x['number']}: {x['status']}" for x in result["applied"]]
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
        ledger.save()
        _snapshot(config, cycle, state, decision, result)
        _log(config,
             f"cycle {cycle}: untriaged={decision['untriaged']} "
             f"applied={len(result['applied'])} dispatched={len(result['dispatched'])} "
             f"latency={decision['latency_s']}s discord={result['discord']}")
        return True
    except ModelError as exc:
        ledger.save()
        _snapshot(config, cycle, None, None, None, error=str(exc))
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
