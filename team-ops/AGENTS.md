# Agents — team-ops

## Sources of truth

| System | Use for | MCP |
|--------|---------|-----|
| **Linear** | Issues, cycles, status, who owns what | Linear remote MCP |
| **GitHub** | Code, PRs, CI, reviews | GitHub MCP / `gh` |
| **Discord** | Standups, alerts, human chat | Discord MCP bot; else CDP **9230** |

Linear only for **active / scheduled / delegated** work. Not every GitHub issue needs Linear.

## ID convention (mandatory)

- Linear key pattern: `TEAM-n` (or workspace prefix once set)
- Branch: `team-n-short-slug` (lowercase)
- PR title: `[TEAM-n] description`
- Discord: always include `TEAM-n` when discussing work

## Browser (persistent — this project)

| | |
|--|--|
| CDP | **`http://127.0.0.1:9230`** |
| Session | `hackathon` |
| Profile | `~/Desktop/hackathon/browser/profile/` |
| Pin files | `config/browser.env`, hackathon `config/cdp.env` |

Never use daily Brave **9223**. Scripts auto-load browser pins via `scripts/lib.sh`.

**Tab rule:** do **not** open new tabs for GitHub / Linear / Discord if a tab on that host is already open. Reuse and activate. `open-sites.sh` enforces this.

## GitHub auth (gh CLI)

| | |
|--|--|
| Owner | **TimothyVang** |
| Auth | `gh` keyring — scripts call real `gh` binary and export token at runtime |
| Config | `config/github.env` |

Do not put long-lived tokens in git. Prefer `gh auth token` via `auth_github_from_gh`.

## Discord

- Invite (humans): https://discord.gg/9FFySeV8B
- Bot: env `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`
- Fallback: isolated Brave **http://127.0.0.1:9230** (hackathon profile)
  - `../../../scripts/open-sites.sh https://discord.com/app` from hackathon root
  - or agent-browser `--cdp http://127.0.0.1:9230 --session hackathon`

## Keep the tracker current (update when a task is done)

As the **last step of any task — before marking it complete —** update tracking so
status never drifts. Board index: [`../HUB.md`](../HUB.md).

1. **GitHub (tracker of record):**
   - Reference the issue from the PR/commit (`Closes #<n>`) and close or re-label it.
   - Move its card to **Done** on the Clawforge Project board.
2. **Linear (mirror):** reflect the same status via the Linear MCP.
   > NOTE (2026-07-18): Linear MCP is **not wired** (removed) and the Linear project
   > was **canceled** — see [`CONNECTIONS.md`](CONNECTIONS.md). Skip this step until
   > Linear is re-wired. (The "Linear (live)" and `TEAM-n`/`PUG-n` sections below are
   > historical and no longer active.)

## Before acting

1. Read `config/team.yaml` for members and channel IDs
2. Prefer MCP tools over scraping
3. Never print secrets (tokens, PATs)
4. After creating Linear issue + GitHub PR, post a one-liner to `#dev` or `#linear`

## Connect a new project

```bash
./scripts/connect-project.sh <name>
```

Or use prompt `config/prompts/connect-repo.md`.

## Prompt pack

Use files in `config/prompts/` as system/user prompts. Start with `00-system.md`.


## Linear (live)

- Workspace: **pugtest**
- Team: **PUGtest** (key **PUG**)
- Project: **team-ops** — https://linear.app/pugtest/project/team-ops-1cc18af37fc0
- Issues: `PUG-n`
