"""Runtime configuration for clawforge, read from environment at instantiation.

Nothing here is secret: the model endpoint is a local URL, GitHub auth comes from
the `gh` CLI at runtime, and any Discord token is read from the process env only.
Reading env in __init__ (not class-level defaults) lets CLI/env overrides apply.
"""
from __future__ import annotations

import os
from pathlib import Path


def _root() -> Path:
    # clawforge/src/clawforge/config.py -> clawforge/
    return Path(__file__).resolve().parents[2]


def _load_dotenv() -> None:
    """Load src/.env into the environment (without overriding real env vars)."""
    env_path = Path(__file__).resolve().parents[1] / ".env"  # src/.env
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip().strip('"').strip("'"))


_load_dotenv()


def _flag(name: str, default: str = "0") -> bool:
    return os.environ.get(name, default) == "1"


class Config:
    def __init__(self) -> None:
        # --- model / brain (swappable, OpenAI-compatible) ---
        self.base_url = os.environ.get("CLAWFORGE_MODEL_BASE_URL", "http://localhost:8001/v1")
        self.model = os.environ.get("CLAWFORGE_MODEL", "clawforge-brain")
        self.api_key = os.environ.get("CLAWFORGE_MODEL_API_KEY", "EMPTY")
        self.request_timeout = int(os.environ.get("CLAWFORGE_MODEL_TIMEOUT", "90"))
        # Rate-limit (HTTP 429) handling: back off and retry rather than failing
        # the cycle. Backoff = base * 2**attempt, capped, plus any Retry-After.
        self.model_max_retries = int(os.environ.get("CLAWFORGE_MODEL_MAX_RETRIES", "3"))
        self.model_retry_base = float(os.environ.get("CLAWFORGE_MODEL_RETRY_BASE", "1.0"))
        self.model_retry_cap = float(os.environ.get("CLAWFORGE_MODEL_RETRY_CAP", "30.0"))

        # --- GitHub (tracker of record) ---
        self.owner = os.environ.get("CLAWFORGE_OWNER", "TimothyVang")
        self.repo = os.environ.get("CLAWFORGE_REPO", "clawforge")          # PM watches
        self.work_repo = os.environ.get("CLAWFORGE_WORK_REPO", "tickytalky")  # dispatch target
        # Extra projects to track (triage + board + Discord), comma-separated.
        self.track_repos = [
            r.strip() for r in os.environ.get("CLAWFORGE_TRACK_REPOS", "").split(",") if r.strip()
        ]
        self.project_number = int(os.environ.get("CLAWFORGE_PROJECT", "1"))

        # --- heartbeat ---
        self.interval_seconds = int(os.environ.get("CLAWFORGE_INTERVAL", "60"))
        self.max_cycles = int(os.environ.get("CLAWFORGE_MAX_CYCLES", "0"))  # 0 = forever

        # --- actions ---
        self.dry_run = _flag("CLAWFORGE_DRY_RUN")
        self.dispatch_enabled = _flag("CLAWFORGE_DISPATCH")

        # --- output ---
        # Emit a machine-readable JSON record of each cycle to stdout (human logs
        # go to stderr). Set by the `--json` CLI flag.
        self.json_output = _flag("CLAWFORGE_JSON")

        # --- discord (optional; skipped if unset) ---
        self.discord_bot_token = os.environ.get("DISCORD_BOT_TOKEN", "")
        self.discord_channel_id = os.environ.get("CLAWFORGE_DISCORD_CHANNEL", "")

        # --- state / logs ---
        self.state_dir = Path(
            os.environ.get("CLAWFORGE_STATE_DIR", str(_root() / ".generated" / "clawforge"))
        )

    def _full(self, name: str) -> str:
        return name if "/" in name else f"{self.owner}/{name}"

    @property
    def watched_repo(self) -> str:
        return self._full(self.repo)

    @property
    def watched_repos_full(self) -> list[str]:
        """Primary watched repo first, then any extra tracked projects."""
        return [self.watched_repo] + [self._full(r) for r in self.track_repos]

    @property
    def work_repo_full(self) -> str:
        return self._full(self.work_repo)

    def ensure_dirs(self) -> None:
        self.state_dir.mkdir(parents=True, exist_ok=True)

    @property
    def ledger_path(self) -> Path:
        return self.state_dir / "ledger.json"

    @property
    def log_path(self) -> Path:
        return self.state_dir / "clawforge.log"

    @property
    def snapshot_path(self) -> Path:
        return self.state_dir / "latest-cycle.md"

    @property
    def json_snapshot_path(self) -> Path:
        return self.state_dir / "latest-cycle.json"

    @property
    def history_path(self) -> Path:
        """Append-only JSONL of every cycle record (audit trail across cycles)."""
        return self.state_dir / "cycle-history.jsonl"


CONFIG = Config()
