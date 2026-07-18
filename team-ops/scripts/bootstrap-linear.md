# Bootstrap Linear (greenfield)

Linear has no fully unattended CLI create for workspaces. Do this once as **Lead**.

## 1. Create workspace

1. https://linear.app → sign up / create workspace  
2. Note workspace URL slug (e.g. `my-team`) → `LINEAR_WORKSPACE` in `.env`

## 2. Team

1. Create team **Core** (or set `LINEAR_TEAM` to your name)
2. Invite 5 members (email)
3. Optional: set issue key prefix (e.g. `TEAM`) in team settings

## 3. Labels

Import ideas from `templates/linear-labels.yaml` (create matching labels in UI or via agent + Linear MCP).

## 4. Connect Linear MCP

**Claude Code:**

```bash
claude mcp add --transport http linear-server https://mcp.linear.app/mcp
# then /mcp in session to OAuth
```

**Grok / others:** merge `config/mcp/grok.toml` or `.generated/grok.mcp.toml` after `install.sh`.

**API key (optional scripts):** https://linear.app/settings/api → `LINEAR_API_KEY` in `.env`

## 5. Agent bootstrap prompt

Paste into any agent with Linear MCP connected:

```
Using Linear MCP on team Core:
1. Ensure labels: bug, feature, chore, priority-urgent, priority-high
2. Create project "Team Ops Meta" with summary "PM space for GitHub+Discord"
3. Create issues: onboard 5 members, configure Discord bot, first app connect-project
Return issue identifiers.
```

## 6. Verify

- Linear MCP: list teams / list issues  
- `./scripts/doctor.sh` shows LINEAR warnings clear when key or OAuth ready
