# Setup — team of 5 (greenfield)

## 0. Prerequisites (each person)

- Git
- Node.js 20+
- [GitHub CLI](https://cli.github.com/) (`gh`)
- One of: Claude Code, Grok, OpenCode, Codex

## 1. Clone / open this folder

```bash
cd clawforge/team-ops   # after: git clone https://github.com/TimothyVang/clawforge.git
```

## 2. Install tooling + MCP configs

**Linux / macOS**

```bash
./scripts/install.sh
./scripts/doctor.sh
```

**Windows**

```powershell
.\scripts\install.ps1
.\scripts\doctor.ps1
```

## 3. Secrets (local only)

```bash
cp .env.example .env
# edit .env — never commit
```

| Variable | Who needs it | How |
|----------|--------------|-----|
| `GITHUB_TOKEN` or `gh auth login` | Everyone with write | `gh auth login` preferred |
| Linear OAuth via MCP | Everyone | First agent session → Linear connector |
| `LINEAR_API_KEY` | Optional scripts | Linear → Settings → API |
| `DISCORD_BOT_TOKEN` | One shared bot | [discord/bot-setup.md](discord/bot-setup.md) |
| `DISCORD_GUILD_ID` | Shared | Discord server settings → copy ID |

## 4. Discord (communication)

1. Join: **https://discord.gg/9FFySeV8B**
2. Create channels (see [discord/channel-map.md](discord/channel-map.md))
3. Create bot and invite it ([discord/bot-setup.md](discord/bot-setup.md))
4. Paste token + guild ID into `.env`
5. Put channel snowflake IDs into `config/team.yaml`

If the bot is not ready, agents use browser fallback on CDP **9230**.

## 5. Linear (project management)

Follow [scripts/bootstrap-linear.md](scripts/bootstrap-linear.md):

1. Create workspace at https://linear.app
2. Create team **Core** (or rename; set `LINEAR_TEAM` in `.env`)
3. Invite 5 members
4. Connect Linear MCP in your agent client
5. Run agent prompt `config/prompts/new-project.md` or create labels from `templates/linear-labels.yaml`

## 6. GitHub (code)

```bash
# set GITHUB_OWNER in .env (user or org)
export GITHUB_OWNER=your-org-or-user
./scripts/bootstrap-github.sh
```

Invites for 5 collaborators are printed; accept them in GitHub email/UI.

## 7. Fill team roster

Edit `config/team.yaml` with names, GitHub handles, Linear emails, Discord IDs.

## 8. Connect your first app repo

```bash
./scripts/connect-project.sh demo-app
```

## 9. Daily loop

| When | Prompt |
|------|--------|
| Morning | `config/prompts/standup.md` |
| New feature | `new-project.md` / Linear issue → branch `team-n-…` |
| PR ready | `ship-pr.md` |
| Friday | `weekly-status.md` |

## Checklist (lead)

- [ ] Discord server channels created
- [ ] Bot invited with message permissions
- [ ] Linear workspace + Core team + 5 invites
- [ ] GitHub owner set; meta repo pushed
- [ ] All 5 ran `install` + `doctor`
- [ ] `team.yaml` filled
- [ ] First project connected
