# Prompt — triage GitHub ↔ Linear

For open PRs and issues in `{GITHUB_OWNER}` (or listed repos):

1. Classify each item:
   - **Merge** — ready / nearly ready
   - **Port** — idea good, rebuild in our stack
   - **Close** — stale, wrong, duplicate
   - **Park** — later, not this cycle
2. Create or update **Linear only** for Merge/Port that are scheduled this cycle.
3. Use IDs `TEAM-n` in PR titles/comments when linking.
4. Post a triage summary to Discord **#dev**.

Do not dump the entire backlog into Linear.
