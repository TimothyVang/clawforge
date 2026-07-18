# team-ops Discord MCP

Stdio MCP server for Discord bot messaging.

## Tools

| Tool | Description |
|------|-------------|
| `discord_status` | Bot identity / config check |
| `discord_list_channels` | List text channels in guild |
| `discord_send_message` | Post to channel ID |
| `discord_read_messages` | Recent messages |
| `discord_create_thread` | Create thread |

## Setup

```bash
cd mcp/discord
npm install
export DISCORD_BOT_TOKEN=…
export DISCORD_GUILD_ID=…
node src/index.js
```

Without a token, tools return a clear error and point to browser CDP **9230**.

## Wire into agents

See `config/mcp/*.json` and run `../../scripts/install.sh`.
