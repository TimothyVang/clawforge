# Discord channel map

Invite: https://discord.gg/9FFySeV8B

Create these channels (names exact for docs/scripts):

| Channel | Purpose | Env key |
|---------|---------|---------|
| `#general` | Human chat | — |
| `#standup` | Daily standup posts | `DISCORD_CHANNEL_STANDUP` |
| `#dev` | PRs, builds, ship notes | `DISCORD_CHANNEL_DEV` |
| `#alerts` | CI / urgent Linear | `DISCORD_CHANNEL_ALERTS` |
| `#linear` | Issue create/close notes | `DISCORD_CHANNEL_LINEAR` |
| `#agent` | Optional agent playground | — |
| `#proj-<slug>` | Per-app (created by connect-project) | team.yaml |

Paste snowflake IDs into `config/team.yaml` → `discord.channels`.
