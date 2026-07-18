"""Persistent state so the agent survives restarts and never re-acts on the same work.

A tiny JSON ledger of what the agent has already acted on, plus a cycle counter.
This is what makes clawforge "persistent with context" across cycles (a Claw pillar).
"""
from __future__ import annotations

import json
from typing import Any

from .config import Config, CONFIG


class Ledger:
    def __init__(self, config: Config = CONFIG):
        self.cfg = config
        self.path = config.ledger_path
        self._data: dict[str, Any] = self._load()

    def _load(self) -> dict[str, Any]:
        if self.path.exists():
            try:
                return json.loads(self.path.read_text())
            except (ValueError, OSError):
                pass
        return {"acted": {}, "cycles": 0}

    def save(self) -> None:
        self.cfg.ensure_dirs()
        self.path.write_text(json.dumps(self._data, indent=2, sort_keys=True))

    # --- acted-on tracking (idempotency) ---
    def has_acted(self, key: str) -> bool:
        return key in self._data["acted"]

    def record(self, key: str, note: str = "") -> None:
        self._data["acted"][key] = note

    # --- cycles ---
    @property
    def cycles(self) -> int:
        return self._data["cycles"]

    def bump_cycle(self) -> int:
        self._data["cycles"] += 1
        return self._data["cycles"]
