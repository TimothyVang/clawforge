# Prompt — daily standup

Using Linear MCP:

1. List issues for team **Core** (or `LINEAR_TEAM`) in states Todo / In Progress / In Review.
2. Group by assignee (use `config/team.yaml` roster).
3. Note blockers and anything stale (>3 days no update).

Post a short message to Discord **#standup** via Discord MCP:

```
**Standup {date}**
• @{person}: TEAM-n title (status)
• Blockers: …
```

If Discord MCP is unavailable, open Discord on CDP `http://127.0.0.1:9230` and draft the same text for the user to paste, or post if browser automation is allowed.

Do not invent issues that are not in Linear.
