# CONNECTIONS — live mesh

Status hub for **team-ops**. Everything points at everything.

> **Tracker of record: GitHub.** Linear was retired 2026-07-18 — issues, PRs, and
> project tracking now live on GitHub (a cross-repo Project board is the single
> view once the `project` scope is granted; see [`../HUB.md`](../HUB.md)). The
> Linear rows below are kept as history, not live surfaces.

## Triangle

| Surface | Endpoint | Status |
|---------|----------|--------|
| **GitHub** | https://github.com/TimothyVang/team-ops | Connected (`gh` as TimothyVang) |
| **Linear** | ~~PUGtest / team-ops~~ | **Canceled** 2026-07-18 (team not deleted) |
| **Linear project** | team-ops | **Canceled** |
| **Discord** | **HACKATHON TEAM** · https://discord.gg/9FFySeV8B · guild `1527816191148818522` | Wired; bot optional |
| **Browser** | CDP `http://127.0.0.1:9230` session `hackathon` | Isolated profile + SSO |
| **Local** | `clawforge/team-ops/` (in product repo) | Source of truth for scripts |

## Issue map (Linear ↔ GitHub)

| Linear | GitHub | Title |
|--------|--------|--------|
| [PUG-210](https://linear.app/pugtest/issue/PUG-210) | [#1](https://github.com/TimothyVang/team-ops/issues/1) | Onboard team of 5 |
| [PUG-209](https://linear.app/pugtest/issue/PUG-209) | [#2](https://github.com/TimothyVang/team-ops/issues/2) | Discord bot + channel IDs |
| [PUG-208](https://linear.app/pugtest/issue/PUG-208) | [#3](https://github.com/TimothyVang/team-ops/issues/3) | Connect first app repo |

## ID convention

```
PUG-n  ↔  GitHub issue [PUG-n] …  ↔  branch pug-n-slug  ↔  PR [PUG-n] …
Discord messages mention PUG-n
```

## Auth

| System | How |
|--------|-----|
| GitHub | `gh auth login` → scripts export token via `auth_github_from_gh` |
| Linear | MCP OAuth in agent client (optional `LINEAR_API_KEY`) |
| Discord bot | `DISCORD_BOT_TOKEN` in `.env` (see `discord/bot-setup.md`) |
| Discord fallback | Browser CDP 9230 |

## Config pins

| File | Content |
|------|---------|
| `config/github.env` | `GITHUB_OWNER=TimothyVang` |
| `config/linear.env` | team/project IDs + URLs |
| `config/browser.env` | CDP 9230 |
| `config/team.yaml` | roster + linear block |
| `.mcp.json` | Claude MCP snippets |

## Re-verify

```bash
./scripts/connect-all.sh
# or
./scripts/doctor.sh
```

## Still optional (human)

1. Discord bot token + guild/channel snowflakes → full Discord MCP posts  
2. Invite 4 teammates on Linear / GitHub / Discord  
3. `./scripts/connect-project.sh <app>` for first product repo

## E2E automation

```bash
./scripts/e2e.sh
```

Last controlled run: **14 PASS / 1 WARN / 0 FAIL** (`ok: true`).

| Leg | Result |
|-----|--------|
| GitHub gh auth + issues + comment | PASS |
| Linear project + issues (MCP) | PASS |
| Browser CDP 9230 tabs | PASS |
| doctor / connect-all / connect-project | PASS |
| Discord bot MCP | WARN (no token; browser fallback PASS) |

Artifacts: `/tmp/team-ops-e2e/report.json`

## Discord server

| | |
|--|--|
| Name | **HACKATHON TEAM** |
| Invite | https://discord.gg/9FFySeV8B |
| Guild | `1527816191148818522` |
| #general | `1527816191588958221` |
| Standup | `#session-planning` `1527816191588958223` |
| Notes | `#notes-resources` `1527816191588958219` |

Full map: [discord/SERVER.md](discord/SERVER.md)


## Linear canceled (2026-07-18)

- Project **team-ops** → Canceled
- Issues PUG-208, PUG-209, PUG-210, PUG-211 → Canceled
- Team **PUGtest** still exists (only team in workspace; MCP cannot delete teams)
- **Warning:** PUGtest also contains older non-team-ops issues (e.g. Rust-DFIR). Deleting the whole team in Linear UI would remove those too.

To delete the team yourself: Linear → Settings → Teams → PUGtest → Delete.

## TeamSync (oneshot)

```bash
./scripts/teamsync.sh
```

- Script: `scripts/teamsync.sh`
- Prompt: `config/prompts/teamsync.md`
- Report: `.generated/teamsync-latest.md`
- Reuses browser tabs on CDP 9230 (no spam)

