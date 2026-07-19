"""SENSE — read the current world state the PM agent reasons about.

Open issues (+ labels/body) and PRs in the watched repo, plus open issues in the
work repo (the dispatch target). GitHub is the tracker of record; auth via `gh`.
"""
from __future__ import annotations

from typing import Any

from .config import Config, CONFIG
from .gh import gh


def _issues(repo: str, limit: int = 30, state: str = "open") -> list[dict[str, Any]]:
    try:
        return gh(
            "issue", "list", "--repo", repo, "--state", state,
            "--json", "number,title,labels,body,url", "--limit", str(limit),
            json_out=True,
        ) or []
    except RuntimeError:
        return []


def _prs(repo: str, limit: int = 30) -> list[dict[str, Any]]:
    try:
        return gh(
            "pr", "list", "--repo", repo, "--state", "open",
            "--json", "number,title,url,isDraft", "--limit", str(limit),
            json_out=True,
        ) or []
    except RuntimeError:
        return []


def read_state(config: Config = CONFIG) -> dict[str, Any]:
    watched_full = config.watched_repos_full  # primary + extra tracked projects
    work = config.work_repo_full
    # Sense every watched repo's open + recently-closed issues.
    watched = [
        {"repo": r, "open": _issues(r), "closed": _issues(r, limit=20, state="closed")}
        for r in watched_full
    ]
    primary = watched[0]
    state = {
        "repo": watched_full[0],
        "work_repo": work,
        "watched": watched,
        # Backward-compat aliases pointing at the primary watched repo.
        "issues": primary["open"],
        "closed_issues": primary["closed"],
        "work_issues": _issues(work),
        "closed_work_issues": _issues(work, limit=20, state="closed"),
        "prs": _prs(watched_full[0]),
    }
    state["counts"] = {
        "issues": sum(len(w["open"]) for w in watched),  # total across watched repos
        "work_issues": len(state["work_issues"]),
        "prs": len(state["prs"]),
    }
    return state


def watched_open_groups(state: dict[str, Any]) -> list[tuple[str, list[dict[str, Any]]]]:
    """(repo, open_issues) for every watched repo plus the work repo."""
    groups = [(w["repo"], w["open"]) for w in state.get("watched", [])]
    groups.append((state["work_repo"], state.get("work_issues", [])))
    return groups


def watched_closed_groups(state: dict[str, Any]) -> list[tuple[str, list[dict[str, Any]]]]:
    """(repo, closed_issues) for every watched repo plus the work repo."""
    groups = [(w["repo"], w["closed"]) for w in state.get("watched", [])]
    groups.append((state["work_repo"], state.get("closed_work_issues", [])))
    return groups


def label_names(issue: dict[str, Any]) -> list[str]:
    return [lbl.get("name", "") for lbl in issue.get("labels", [])]


def read_milestones(repos: list[str]) -> list[dict[str, Any]]:
    """Open GitHub milestones across repos: [{repo, title, open, closed}]."""
    out: list[dict[str, Any]] = []
    for r in repos:
        try:
            ms = gh("api", f"repos/{r}/milestones?state=open", json_out=True) or []
        except RuntimeError:
            continue
        for m in ms:
            out.append({
                "repo": r, "title": m.get("title", ""),
                "open": m.get("open_issues", 0), "closed": m.get("closed_issues", 0),
            })
    return out
