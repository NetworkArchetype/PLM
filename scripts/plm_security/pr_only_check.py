#!/usr/bin/env python3
"""CI guardrail: ensure pushes to master come from a merged PR.

This is designed to be used with GitHub branch protection:
- Require status check "enforce-pr-only" to pass on `master`.

Without branch protection, this will still run on pushes and report failure,
but cannot *prevent* the push.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request


def _env(name: str) -> str:
    v = os.environ.get(name) or ""
    return v.strip()


def _github_api_get(url: str, token: str) -> object:
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {token}")
    # Commits -> pulls is historically preview; keep compat header.
    req.add_header("Accept", "application/vnd.github.groot-preview+json")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _has_merged_pr(repo_full: str, sha: str, token: str, base_ref: str) -> bool:
    pulls = _github_api_get(
        f"https://api.github.com/repos/{repo_full}/commits/{sha}/pulls",
        token,
    )

    if not isinstance(pulls, list):
        return False

    for pr in pulls:
        try:
            merged_at = pr.get("merged_at")
            base = (pr.get("base") or {}).get("ref")
            if merged_at and base == base_ref:
                return True
        except Exception:
            continue

    return False


def main() -> int:
    repo_full = _env("GITHUB_REPOSITORY")
    sha = _env("GITHUB_SHA")
    token = _env("GITHUB_TOKEN")
    ref = _env("GITHUB_REF")
    event_name = _env("GITHUB_EVENT_NAME")

    # Only enforce on pushes to master.
    if event_name != "push":
        print("Not a push event; skipping.")
        return 0

    if ref not in ("refs/heads/master",):
        print(f"Not master ({ref}); skipping.")
        return 0

    if not repo_full or not sha or not token:
        sys.stderr.write("Missing required env vars: GITHUB_REPOSITORY/GITHUB_SHA/GITHUB_TOKEN\n")
        return 2

    if _has_merged_pr(repo_full, sha, token, base_ref="master"):
        print("OK: push to master is associated with a merged PR.")
        return 0

    sys.stderr.write("Denied: direct pushes to master are not allowed.\n")
    sys.stderr.write("Create a branch, open a PR, and merge it instead.\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
