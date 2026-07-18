# Prompt — ship PR

For PR `{PR_URL_OR_NUMBER}` (or current branch):

1. Ensure title starts with `[TEAM-n]` and branch matches `team-n-…`.
2. Confirm Linear issue TEAM-n is In Review or Done-ready; comment with PR link.
3. Check CI status; request review from codeowners / seat lead if needed.
4. Post to Discord **#dev**:

```
🚢 [TEAM-n] {title}
PR: {url}
Review: @{github}
```

5. On merge: move Linear to Done; optional #linear note.
