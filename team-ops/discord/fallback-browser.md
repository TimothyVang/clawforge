# Discord browser fallback (no bot token)

Uses the **hackathon isolated browser**:

| | |
|--|--|
| CDP | `http://127.0.0.1:9230` |
| Session | `hackathon` |
| Profile | `~/Desktop/hackathon/browser/profile/` |

## Start + open Discord

```bash
cd ~/Desktop/hackathon
./scripts/browser-start.sh
./scripts/open-sites.sh https://discord.com/app
# if SSO stale:
make import-sso
```

## Agent attach

```bash
agent-browser --cdp http://127.0.0.1:9230 --session hackathon snapshot
```

Or Patchright MCP: `~/Desktop/hackathon/scripts/patchright-mcp.sh`

## When to use

- Bot token not ready yet
- Need human login / 2FA
- Read-only glance at channels

Prefer the **bot MCP** for automated posts once configured.
