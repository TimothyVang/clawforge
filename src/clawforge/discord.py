"""Discord posting via the bot API.

Reads the bot token from env or ~/.config/clawforge/DISCORD_BOT_TOKEN.txt, and the
target channel ids from ~/.config/clawforge/discord_channels.json (keys: status,
next-tasks, done). Skips gracefully (returns 'skipped') when nothing is configured,
so the agent still runs without Discord. Chunks messages to Discord's 2000 limit.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import requests

from .config import Config, CONFIG

API = "https://discord.com/api/v10"
_TOKEN_FILE = Path.home() / ".config" / "clawforge" / "DISCORD_BOT_TOKEN.txt"
_CHAN_FILE = Path.home() / ".config" / "clawforge" / "discord_channels.json"


def _token(config: Config) -> str:
    if config.discord_bot_token:
        return config.discord_bot_token
    try:
        return _TOKEN_FILE.read_text().strip()
    except OSError:
        return ""


def _channels() -> dict:
    try:
        return json.loads(_CHAN_FILE.read_text())
    except (OSError, ValueError):
        return {}


def _send(token: str, channel_id: str, content: str) -> str:
    headers = {"Authorization": f"Bot {token}"}
    # Discord hard limit is 2000 chars per message; chunk on line boundaries.
    chunks, buf = [], ""
    for line in content.splitlines(keepends=True):
        if len(buf) + len(line) > 1900:
            chunks.append(buf); buf = ""
        buf += line
    if buf:
        chunks.append(buf)
    for ch in chunks or [content[:1900]]:
        try:
            r = requests.post(f"{API}/channels/{channel_id}/messages",
                              headers=headers, json={"content": ch[:1990]}, timeout=12)
            if r.status_code >= 300:
                return f"failed HTTP {r.status_code}"
        except requests.RequestException as exc:
            return f"failed ({exc})"
    return "posted"


def post_to(channel_key: str, content: str, config: Config = CONFIG) -> str:
    """Post to a named channel (status/next-tasks/done)."""
    token = _token(config)
    cid = _channels().get(channel_key) or config.discord_channel_id
    if not token or not cid or not content.strip():
        return "skipped"
    return _send(token, cid, content)


def post(content: str, config: Config = CONFIG) -> str:
    """Back-compat: post to the status channel (or configured single channel)."""
    return post_to("status", content, config)
