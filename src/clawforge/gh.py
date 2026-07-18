"""Thin wrapper around the `gh` CLI — reuses the team-ops auth model.

GitHub auth comes from `gh` at runtime (keyring); no tokens are stored here.
Resolves the real `gh` binary path-agnostically (mirrors team-ops lib.sh gh_bin).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from functools import lru_cache
from typing import Any


@lru_cache(maxsize=1)
def gh_bin() -> str:
    candidates = [
        shutil.which("gh"),
        os.path.expanduser("~/.local/bin/gh"),
        "/usr/bin/gh",
        "/usr/local/bin/gh",
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    raise RuntimeError("gh CLI not found on PATH")


def gh(*args: str, check: bool = True, json_out: bool = False, timeout: int = 60) -> Any:
    proc = subprocess.run(
        [gh_bin(), *args], capture_output=True, text=True, timeout=timeout
    )
    if check and proc.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed: {proc.stderr.strip()[:400]}")
    if json_out:
        return json.loads(proc.stdout or "null")
    return proc.stdout
