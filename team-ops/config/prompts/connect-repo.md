# Prompt — connect existing repo

Connect local or remote repo `{PATH_OR_OWNER_REPO}` to team-ops:

1. Run `./scripts/connect-project.sh {slug}` (or perform equivalent steps).
2. Create Linear project if missing; link in PROJECT.md.
3. Ensure GitHub remote + PR template present.
4. Map Discord channel; announce in #dev.
5. Append entry under `projects:` in `config/team.yaml`.

Confirm with a three-link checklist: Linear | GitHub | Discord.
