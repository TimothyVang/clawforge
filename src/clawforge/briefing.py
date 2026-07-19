"""BRIEFING — a high-level, visual project-manager status for Discord.

Renders the live Project board as an at-a-glance briefing: an overall progress
bar, the board as a Todo / In Progress / Done checklist, GitHub milestones (when
defined), and what the agent did this cycle. Pure markdown + emoji so Discord
renders it richly. Everything is derived from real board/GitHub data — no
invented milestones or goals.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

_COLUMN_ORDER = ["Todo", "In Progress", "Done"]
_COL_EMOJI = {"Todo": "📋", "In Progress": "🔨", "Done": "✅"}
_ITEM_EMOJI = {"Todo": "⬜", "In Progress": "🔧", "Done": "✅"}
_MAX_PER_COL = 8


def _bar(done: int, total: int, width: int = 16) -> str:
    """A text progress bar: `████████░░░░░░░░` 50% (4/8)."""
    if total <= 0:
        return "`" + "░" * width + "` —"
    filled = round(width * done / total)
    pct = round(100 * done / total)
    return f"`{'█' * filled}{'░' * (width - filled)}` {pct}% ({done}/{total})"


def _short(repo: str) -> str:
    return repo.split("/")[-1] if repo else "?"


def _group_by_status(items: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for it in items:
        grouped.setdefault(it.get("status") or "No status", []).append(it)
    return grouped


def _this_cycle(result: dict[str, Any]) -> list[str]:
    out: list[str] = []
    for a in result.get("applied", []):
        if str(a.get("status", "")).startswith("labeled"):
            out.append(f"- 🏷️ Triaged `{_short(a['repo'])}#{a['number']}` → {a['label']}")
    for d in result.get("dispatched", []):
        if d.get("status") == "PR":
            out.append(f"- 🔨 Opened PR for #{d['number']} — {d.get('pr', '')}")
    for d in result.get("done", []):
        out.append(f"- ✅ Completed `{_short(d['repo'])}#{d['number']}`")
    return out


def pm_briefing(
    state: dict[str, Any],
    result: dict[str, Any],
    board_items: list[dict[str, Any]],
    milestones: list[dict[str, Any]] | None = None,
    todos: dict[str, list[str]] | None = None,
    ts: str | None = None,
) -> str:
    ts = ts or datetime.now(timezone.utc).strftime("%H:%M UTC")
    grouped = _group_by_status(board_items)
    total = len(board_items)
    done = len(grouped.get("Done", []))

    lines = [
        "# 🐾 Clawforge — PM Briefing",
        f"_{ts}_",
        "",
        "## 📁 Projects",
    ]
    for w in state.get("watched", []):
        lines.append(f"- **{w['repo']}** · watched")
    if state.get("work_repo"):
        lines.append(f"- **{state['work_repo']}** · work (auto-PRs)")
    lines += [
        "",
        "## 📊 Overall progress",
        _bar(done, total),
        "",
        "## 🗂️ Board",
    ]
    for col in _COLUMN_ORDER:
        col_items = grouped.get(col, [])
        lines.append(f"**{_COL_EMOJI[col]} {col} — {len(col_items)}**")
        if not col_items:
            lines.append("> _empty_")
        for it in col_items[:_MAX_PER_COL]:
            lines.append(f"> {_ITEM_EMOJI[col]} `{_short(it['repo'])}#{it['number']}` {it['title']}")
        if len(col_items) > _MAX_PER_COL:
            lines.append(f"> _…+{len(col_items) - _MAX_PER_COL} more_")
        lines.append("")

    lines.append("## 🎯 Milestones / Goals")
    if milestones:
        for m in milestones:
            lines.append(f"**{_short(m['repo'])} · {m['title']}**  "
                         f"{_bar(m['closed'], m['open'] + m['closed'])}")
    else:
        lines.append("_No GitHub milestones set — headline goal: clear all tracked work._")
        lines.append(f"Done so far: {_bar(done, total)}")
    lines.append("")

    if todos:
        lines.append("## 📝 Suggested to-dos")
        for repo, items in todos.items():
            lines.append(f"**{_short(repo)}**")
            for t in items:
                lines.append(f"- [ ] {t}")
        lines.append("")

    cycle = _this_cycle(result)
    if cycle:
        lines.append("## 🔄 What I did this cycle")
        lines += cycle

    return "\n".join(lines).strip() + "\n"
