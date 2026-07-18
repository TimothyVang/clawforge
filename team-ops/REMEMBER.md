# Remember — team-ops browser + GitHub auth

## Browser (persistent for this project)

| Key | Value |
|-----|--------|
| **CDP port** | **9230** |
| **CDP URL** | `http://127.0.0.1:9230` |
| **Session** | `hackathon` |
| **Profile** | `~/Desktop/hackathon/browser/profile/` |
| **Config** | `config/browser.env` + hackathon `config/cdp.env` |
| **Never** | daily Brave **9223** |

Start: `cd ~/Desktop/hackathon && make browser-start`  
SSO re-import: `make import-sso`  
Discord/GitHub in browser: `make open-sites`

## GitHub (gh CLI)

| Key | Value |
|-----|--------|
| **Account** | **TimothyVang** |
| **Owner** | `TimothyVang` |
| **Auth** | `gh` keyring (`gh auth login` already done) |
| **Token source** | runtime: `gh auth token` → scripts export `GITHUB_TOKEN` |
| **Config** | `config/github.env` |

**Shell note:** this machine may alias `gh` to `history|grep`.  
All team-ops scripts use the real binary via `gh_bin` / `ghc` in `scripts/lib.sh`.  
Interactive shells: `unalias gh` or call `~/.local/bin/gh`.

## Verify

```bash
cd ~/Desktop/hackathon/projects/team-ops
./scripts/doctor.sh
# PASS gh authenticated as TimothyVang
# PASS GITHUB_OWNER=TimothyVang
# PASS CDP 9230
```


## Linear (live)

- Workspace: **pugtest**
- Team: **PUGtest** (key **PUG**)
- Project: **team-ops** — https://linear.app/pugtest/project/team-ops-1cc18af37fc0
- Issues: `PUG-n`
