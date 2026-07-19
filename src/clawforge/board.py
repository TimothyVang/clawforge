"""BOARD — move GitHub Projects v2 cards as the agent triages/dispatches.

The GitHub MCP has no Projects tools, so this drives the board via `gh project`.
Field/option ids are discovered at runtime (cached), so it isn't brittle to a
specific board layout. Adding an already-present issue is idempotent.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Any

from .config import Config, CONFIG
from .gh import gh


@lru_cache(maxsize=4)
def _meta(owner: str, number: int) -> dict[str, Any]:
    proj = gh("project", "view", str(number), "--owner", owner, "--format", "json",
              json_out=True)
    fields = gh("project", "field-list", str(number), "--owner", owner,
                "--format", "json", json_out=True)
    status = next(
        (f for f in fields.get("fields", []) if f.get("name") == "Status" and f.get("options")),
        None,
    )
    return {
        "project_id": proj["id"],
        "status_field_id": status["id"] if status else None,
        "options": {o["name"]: o["id"] for o in (status["options"] if status else [])},
    }


def issue_url(repo: str, number: int) -> str:
    return f"https://github.com/{repo}/issues/{number}"


def list_items(config: Config = CONFIG, repos: set[str] | None = None) -> list[dict[str, Any]]:
    """Read the live Project board as [{number, repo, title, url, status, labels}].

    Optionally filter to `repos` (owner/name). Returns [] on any failure so a
    board hiccup never breaks the heartbeat.
    """
    try:
        data = gh("project", "item-list", str(config.project_number), "--owner",
                  config.owner, "--format", "json", "--limit", "200", json_out=True)
    except RuntimeError:
        return []
    out: list[dict[str, Any]] = []
    for it in (data.get("items", []) if isinstance(data, dict) else data) or []:
        c = it.get("content", {}) or {}
        repo = c.get("repository", "")
        if repos is not None and repo not in repos:
            continue
        out.append({
            "number": c.get("number"),
            "repo": repo,
            "title": it.get("title") or c.get("title", ""),
            "url": c.get("url", ""),
            "status": it.get("status") or "No status",
            "labels": it.get("labels", []),
        })
    return out


def move(url: str, status_name: str, config: Config = CONFIG) -> str:
    """Add the issue to the board (if absent) and set its Status. Returns a status str."""
    try:
        m = _meta(config.owner, config.project_number)
    except RuntimeError as exc:
        return f"board-meta-failed: {str(exc)[:60]}"
    if not m["status_field_id"] or status_name not in m["options"]:
        return f"no-status-option:{status_name}"
    try:
        item = gh("project", "item-add", str(config.project_number), "--owner", config.owner,
                  "--url", url, "--format", "json", json_out=True)
        item_id = item.get("id")
        if not item_id:
            return "add-failed"
        gh("project", "item-edit", "--id", item_id, "--project-id", m["project_id"],
           "--field-id", m["status_field_id"],
           "--single-select-option-id", m["options"][status_name])
        return f"card->{status_name}"
    except RuntimeError as exc:
        return f"board-failed: {str(exc)[:80]}"
