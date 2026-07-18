"""TASKS — turn ready issues into copy-paste agent prompts for the next work.

Anyone (a teammate or a coding agent) can grab a prompt and start the next task.
Rendered to a file each cycle and postable to Discord.
"""
from __future__ import annotations

from typing import Any

from .sense import label_names


def agent_prompt(issue: dict[str, Any], repo: str) -> str:
    body = (issue.get("body") or "").strip()
    return (
        f"TASK — {repo}#{issue['number']}: {issue['title']}\n\n"
        f"{body}\n\n"
        f"Do this: implement the change in `{repo}`, keep it minimal and focused, "
        f"then open a PR titled '[clawforge] {issue['title']}' whose body says "
        f"'Closes #{issue['number']}'. Do NOT merge — leave it for review."
    )


def next_tasks(state: dict[str, Any]) -> list[dict[str, Any]]:
    """Ready issues across watched + work repos, as agent-ready prompts."""
    out: list[dict[str, Any]] = []
    for key, repo in (("issues", state["repo"]), ("work_issues", state["work_repo"])):
        for it in state.get(key, []):
            if "triage/ready" in label_names(it):
                out.append({
                    "repo": repo, "number": it["number"], "title": it["title"],
                    "url": it.get("url", ""), "prompt": agent_prompt(it, repo),
                })
    return out


def render_md(tasks: list[dict[str, Any]], state: dict[str, Any]) -> str:
    c = state["counts"]
    lines = [
        f"# Clawforge — next tasks ({len(tasks)} ready)",
        "",
        f"**Left:** {c['issues']} open (watched) + {c['work_issues']} (work) · "
        f"**PRs open:** {c['prs']} · **ready to work:** {len(tasks)}",
        "",
    ]
    for t in tasks:
        lines += [f"## {t['repo']}#{t['number']} — {t['title']}", "", "```", t["prompt"], "```", ""]
    if not tasks:
        lines.append("_No ready tasks — backlog is clear or awaiting triage._")
    return "\n".join(lines) + "\n"


def discord_summary(tasks: list[dict[str, Any]], done: list[dict[str, Any]],
                    dispatched: list[dict[str, Any]], state: dict[str, Any]) -> str:
    """Compact status for a Discord post: done / in-progress / next-up."""
    parts = ["**Clawforge status**"]
    if done:
        parts.append("✅ Done: " + ", ".join(f"{d['repo']}#{d['number']}" for d in done))
    if dispatched:
        parts.append("🔨 In progress (PR opened): " +
                     ", ".join(f"{d['repo']}#{d['number']}" for d in dispatched if d.get("status") == "PR"))
    if tasks:
        parts.append("📋 Ready next: " + ", ".join(f"{t['repo']}#{t['number']} {t['title']}" for t in tasks[:5]))
    else:
        parts.append("📋 No ready tasks queued.")
    return "\n".join(parts)
