"""STATUS — print the most recent cycle snapshot to stdout.

`clawforge --status` reads the markdown snapshot the heartbeat writes at the end
of every cycle (`latest-cycle.md`) and prints it, so you can inspect the agent's
last standup, decisions, and reasoning trace without tailing logs or re-running.

A missing snapshot (no cycle has run yet) is reported as a friendly hint rather
than a crash, so `--status` is always safe to call.
"""
import json

from .config import Config, CONFIG


def latest_markdown(config: Config = CONFIG) -> str | None:
    """The raw latest-cycle snapshot markdown, or None if no cycle has run yet."""
    path = config.snapshot_path
    if not path.exists():
        return None
    return path.read_text()


def latest_json(config: Config = CONFIG) -> str | None:
    """The raw latest-cycle JSON snapshot, or None if no cycle has run yet."""
    path = config.json_snapshot_path
    if not path.exists():
        return None
    return path.read_text()


def render_status(config: Config = CONFIG) -> str:
    """Human-readable last-cycle report for stdout (never raises)."""
    md = latest_markdown(config)
    if md is None:
        return (
            f"No cycle snapshot yet at {config.snapshot_path}.\n"
            "Run a cycle first, e.g. `python3 -m clawforge --once`."
        )
    return md.rstrip("\n")


def render_status_json(config: Config = CONFIG) -> str:
    """Machine-readable last-cycle report for stdout (`--status --json`).

    Emits the persisted JSON snapshot when present; otherwise a small JSON object
    with a `status` hint, so callers always receive parseable JSON (never raises).
    """
    raw = latest_json(config)
    if raw is None:
        return json.dumps(
            {"status": "no-cycle-yet", "snapshot": str(config.json_snapshot_path)},
            sort_keys=True,
        )
    return raw.rstrip("\n")
