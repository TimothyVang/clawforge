"""TODOS — let the model propose concrete next-step to-dos per project.

Clawforge's brain looks at a project's open issues and recent work and proposes a
short, prioritized list of actionable to-dos that are NOT already tracked. These
are suggestions surfaced to the team (display only) — clawforge does not open
them as issues. Kept small and defensive: any model/parse failure yields [].
"""
from __future__ import annotations

from typing import Any

from .client import ModelClient, ModelError
from .decide import _extract_json
from .gh import gh

_SYSTEM = (
    "You are Clawforge, an autonomous software project manager. You propose "
    "concrete next-step to-dos SPECIFIC to the given project, grounded in its "
    "README and description — not generic boilerplate. Respond with ONLY a single "
    "JSON object — no prose, no markdown fences.\n/no_think"
)


def project_context(repo: str, max_chars: int = 1800) -> str:
    """Repo description + README excerpt, so to-dos are project-specific. '' on failure."""
    parts: list[str] = []
    try:
        desc = (gh("api", f"repos/{repo}", "--jq", ".description") or "").strip()
        if desc and desc != "null":
            parts.append(f"Description: {desc}")
    except RuntimeError:
        pass
    try:
        readme = gh("api", f"repos/{repo}/readme", "-H", "Accept: application/vnd.github.raw") or ""
        readme = readme.strip()
        if readme:
            parts.append("README (excerpt):\n" + readme[:max_chars])
    except RuntimeError:
        pass
    return "\n\n".join(parts)


def generate_todos(
    client: ModelClient,
    repo: str,
    open_titles: list[str],
    done_titles: list[str],
    context: str = "",
    max_items: int = 5,
) -> list[str]:
    user = (
        f"Project: {repo}\n"
        + (f"\n{context}\n" if context else "")
        + "\nOpen issues (already tracked — do NOT repeat these):\n"
        + ("\n".join(f"- {t}" for t in open_titles) or "(none)")
        + "\nRecently completed:\n"
        + ("\n".join(f"- {t}" for t in done_titles) or "(none)")
        + f"\n\nBased on THIS project's README and state above, propose {max_items} "
        "concrete, actionable to-do items specific to this project that move it "
        "forward and are NOT already an open issue. Reference real features, files, "
        "or components from the README. Each item <=12 words, imperative voice. "
        'Return JSON exactly like: {"todos":["...","..."]}'
    )
    try:
        res = client.chat(
            [{"role": "system", "content": _SYSTEM}, {"role": "user", "content": user}],
            max_tokens=400, temperature=0.4,
        )
    except ModelError:
        return []
    parsed = _extract_json(res.content) or {}
    raw = parsed.get("todos") if isinstance(parsed, dict) else None
    if not isinstance(raw, list):
        return []
    seen: set[str] = set()
    out: list[str] = []
    for t in raw:
        s = str(t).strip().rstrip(".")
        key = s.lower()
        if s and key not in seen:
            seen.add(key)
            out.append(s[:100])
        if len(out) >= max_items:
            break
    return out


def generate_for_projects(
    client: ModelClient, state: dict[str, Any]
) -> dict[str, list[str]]:
    """{repo: [todo, ...]} for every watched project plus the work repo."""
    from .sense import watched_open_groups, watched_closed_groups

    open_by_repo: dict[str, list[str]] = {}
    for repo, issues in watched_open_groups(state):
        open_by_repo.setdefault(repo, [])
        open_by_repo[repo] += [i.get("title", "") for i in issues]
    done_by_repo: dict[str, list[str]] = {}
    for repo, issues in watched_closed_groups(state):
        done_by_repo.setdefault(repo, [])
        done_by_repo[repo] += [i.get("title", "") for i in issues]

    todos: dict[str, list[str]] = {}
    for repo in open_by_repo:
        ctx = project_context(repo)  # README + description -> project-specific to-dos
        items = generate_todos(
            client, repo, open_by_repo[repo], done_by_repo.get(repo, []), context=ctx
        )
        if items:
            todos[repo] = items
    return todos
