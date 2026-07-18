# team-ops

**Shipped inside [Clawforge](https://github.com/TimothyVang/clawforge)** so every teammate gets the mesh in one clone:

```text
clawforge/
  team-ops/     ← this folder
  judging/
  src/
```

```bash
git clone https://github.com/TimothyVang/clawforge.git
cd clawforge/team-ops
./scripts/install.sh
./scripts/teamsync.sh
```

# team-ops

**Connected** project management for a team of 5:

| Surface | Link |
|---------|------|
| **GitHub** | https://github.com/TimothyVang/team-ops |
| **Linear** | https://linear.app/pugtest/project/team-ops-1cc18af37fc0 |
| **Discord** | **HACKATHON TEAM** · https://discord.gg/9FFySeV8B |
| **Browser** | CDP `http://127.0.0.1:9230` (hackathon isolated) |

Full mesh status: **[CONNECTIONS.md](CONNECTIONS.md)**

## IDs

- Linear team: **PUGtest** · issues **`PUG-n`**
- Branch: `pug-n-slug` · PR: `[PUG-n] …`

## Issue map

| Linear | GitHub |
|--------|--------|
| [PUG-210](https://linear.app/pugtest/issue/PUG-210) | [#1](https://github.com/TimothyVang/team-ops/issues/1) |
| [PUG-209](https://linear.app/pugtest/issue/PUG-209) | [#2](https://github.com/TimothyVang/team-ops/issues/2) |
| [PUG-208](https://linear.app/pugtest/issue/PUG-208) | [#3](https://github.com/TimothyVang/team-ops/issues/3) |

## TeamSync (oneshot)

```bash
./scripts/teamsync.sh          # browser + doctor + mesh report
./scripts/teamsync.sh --check  # no browser open
```

Agent follow-up prompt: `config/prompts/teamsync.md`  
Latest report: `.generated/teamsync-latest.md`

## Quick start

```bash
# Linux / macOS
./scripts/install.sh
./scripts/connect-all.sh
./scripts/doctor.sh

# Windows
.\scripts\install.ps1
.\scripts\doctor.ps1
```

## Agents (MCP)

| MCP | Auth |
|-----|------|
| GitHub | `gh` CLI (TimothyVang) |
| Linear | OAuth / MCP (workspace pugtest) |
| Discord | Bot token **or** browser CDP 9230 |

Configs: `.mcp.json`, `config/mcp/*`, prompts in `config/prompts/`.

## Commands

```bash
./scripts/connect-all.sh          # print full mesh
./scripts/connect-project.sh app  # wire a new product repo
./scripts/bootstrap-github.sh     # ensure GH meta repo
# Linear bootstrap (already live): project team-ops on PUGtest
```

## Docs

- [SETUP.md](SETUP.md) — onboard 5 humans  
- [AGENTS.md](AGENTS.md) — agent rules  
- [REMEMBER.md](REMEMBER.md) — browser + auth pins  
- [CONNECTIONS.md](CONNECTIONS.md) — live links  
