"""Optional Discord standup posting via bot REST.

No-op (returns 'skipped') when DISCORD_BOT_TOKEN / channel are unset — the agent
still runs; the standup lands in the cycle snapshot instead. Mirrors team-ops'
"bot optional, browser fallback" model.
"""
from __future__ import annotations

import requests

from .config import Config, CONFIG


def post(content: str, config: Config = CONFIG) -> str:
    if not config.discord_bot_token or not config.discord_channel_id:
        return "skipped (no token/channel)"
    url = f"https://discord.com/api/v10/channels/{config.discord_channel_id}/messages"
    try:
        r = requests.post(
            url,
            headers={"Authorization": f"Bot {config.discord_bot_token}"},
            json={"content": content[:1900]},
            timeout=10,
        )
        return "posted" if r.status_code < 300 else f"failed HTTP {r.status_code}"
    except requests.RequestException as exc:
        return f"failed ({exc})"
