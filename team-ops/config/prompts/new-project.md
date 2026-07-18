# Prompt — new project (greenfield app)

Create a linked project named **{NAME}** across Linear + GitHub + Discord.

1. **Linear:** Create project `{NAME}` on team Core. Add labels from `templates/linear-labels.yaml` if missing. Create starter issues:
   - TEAM-?: Scaffold repo
   - TEAM-?: CI green
   - TEAM-?: First shippable
2. **GitHub:** Ensure repo `{GITHUB_OWNER}/{slug}` exists (use `bootstrap` / `gh repo create` if needed). Add PR template from `templates/`.
3. **Discord:** Prefer channel `#proj-{slug}` or map to #dev. Announce create in #dev.
4. **Local:** Run or simulate `./scripts/connect-project.sh {slug}` and write `PROJECT.md` with all three links.

Return:

- Linear project URL
- GitHub URL
- Discord channel
- First branch name for issue 1
