"""ACT — apply the model's decisions to the real world, idempotently.

Applies triage labels to issues (creating the label if missing) and posts the
standup. Every action is guarded by the ledger so a restart never re-acts.
"""
from __future__ import annotations

from typing import Any

from . import board
from .config import Config, CONFIG
from .gh import gh
from .ledger import Ledger

_LABEL_COLORS = {
    "triage/ready": "0e8a16",
    "triage/blocked": "b60205",
    "triage/question": "d876e3",
}


def _apply_label(repo: str, number: int, label: str) -> str:
    try:
        gh("issue", "edit", str(number), "--repo", repo, "--add-label", label)
        return "labeled"
    except RuntimeError:
        # Label probably doesn't exist yet — create it, then retry.
        gh("label", "create", label, "--repo", repo, "--force",
           "--color", _LABEL_COLORS.get(label, "ededed"), check=False)
        gh("issue", "edit", str(number), "--repo", repo, "--add-label", label)
        return "labeled(new-label)"


def apply(
    decision: dict[str, Any], ledger: Ledger, config: Config = CONFIG
) -> dict[str, Any]:
    applied: list[dict[str, Any]] = []
    for a in decision.get("actions", []):
        key = f"triage:{a['repo']}#{a['number']}"
        if ledger.has_acted(key):
            continue
        if config.dry_run:
            ledger.record(key, f"dry-run:{a['label']}")
            applied.append({**a, "status": "dry-run"})
            continue
        try:
            status = _apply_label(a["repo"], a["number"], a["label"])
            # Put the triaged issue on the Project board (Todo), once.
            board_key = f"board-todo:{a['repo']}#{a['number']}"
            board_status = ""
            if not ledger.has_acted(board_key):
                board_status = board.move(
                    board.issue_url(a["repo"], a["number"]), "Todo", config)
                ledger.record(board_key, board_status)
            ledger.record(key, a["label"])
            applied.append({**a, "status": status, "board": board_status})
        except RuntimeError as exc:
            applied.append({**a, "status": f"failed: {str(exc)[:100]}"})

    # Discord status/next-tasks posting is owned by the loop (per-channel).
    return {"applied": applied, "discord": "handled-by-loop"}
