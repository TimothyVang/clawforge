# Discord for team-ops

## Server

| | |
|--|--|
| **Name** | **HACKATHON TEAM** |
| **Guild ID** | `1527816191148818522` |
| **Invite** | https://discord.gg/9FFySeV8B |
| **Open** | https://discord.com/channels/1527816191148818522/1527816191588958221 |

This is the Discord for **team-ops** (GitHub `TimothyVang/team-ops` + Linear **PUGtest** / project **team-ops**).

## Channels (live IDs)

Scraped from the open browser session on CDP 9230:

| Channel | ID | team-ops use |
|---------|-----|----------------|
| `#welcome-and-rules` | `1527816191588958218` | Onboarding / rules |
| `#notes-resources` | `1527816191588958219` | Docs / links (Linear, GitHub) |
| `#general` | `1527816191588958221` | Main chat |
| `#homework-help` | `1527816191588958222` | Help / questions |
| `#session-planning` | `1527816191588958223` | **Standups** (maps to standup) |
| `#off-topic` | `1527816191588958224` | Casual |

### Recommended new channels (create if you want cleaner names)

Right-click server → **Create Channel** (or category **team-ops**):

| Create | Purpose | Env key |
|--------|---------|---------|
| `#dev` | PRs, builds, ship notes | `DISCORD_CHANNEL_DEV` |
| `#alerts` | CI / urgent | `DISCORD_CHANNEL_ALERTS` |
| `#linear` | Issue create/close | `DISCORD_CHANNEL_LINEAR` |
| `#agent` | Agent posts | — |

Until those exist, agents can post to:

- standup → `#session-planning`
- status → `#general`
- notes → `#notes-resources`

## Bot (optional, for agent MCP posts)

Follow [bot-setup.md](bot-setup.md). Without a bot token, agents use the isolated browser on CDP **9230**.

## Link triangle

| Surface | URL |
|---------|-----|
| Discord | https://discord.gg/9FFySeV8B |
| GitHub | https://github.com/TimothyVang/team-ops |
| Linear | https://linear.app/pugtest/project/team-ops-1cc18af37fc0 |

Mention work as **`PUG-n`** in Discord messages.
