# Discord bot setup (one shared bot for team of 5)

Human invite (join the server first): **https://discord.gg/9FFySeV8B**

## 1. Create application

1. Open https://discord.com/developers/applications
2. **New Application** → name `team-ops-bot`
3. **Bot** → **Add Bot** → Reset Token → copy into `DISCORD_BOT_TOKEN` in `.env`
4. Disable **Public Bot** if you want invite-only
5. Enable **Message Content Intent** (Bot → Privileged Gateway Intents) if you plan to read message bodies via gateway later; REST read works for bot-visible channels with permissions

## 2. OAuth2 invite URL

OAuth2 → URL Generator:

- Scopes: `bot`, `applications.commands`
- Bot permissions:
  - View Channels
  - Send Messages
  - Read Message History
  - Create Public Threads
  - Embed Links
  - Attach Files (optional)

Open the generated URL while logged in as a server admin and authorize.

## 3. Guild + channel IDs

Discord User Settings → Advanced → **Developer Mode** ON.

- Right-click server → **Copy Server ID** → `DISCORD_GUILD_ID`
- Right-click each channel → **Copy Channel ID** → `config/team.yaml` + `.env`

## 4. Create channels

See [channel-map.md](channel-map.md).

## 5. Verify

```bash
export $(grep -v '^#' .env | xargs)   # careful on shared machines
cd mcp/discord && npm install
# From team-ops root:
./scripts/doctor.sh
```

Agent tool `discord_status` should return the bot username.

## Security

- One bot token for the team; store only in `.env` (gitignored)
- Rotate token if leaked
- Prefer least privilege (no Administrator)
