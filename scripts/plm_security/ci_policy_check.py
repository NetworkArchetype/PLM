#!/usr/bin/env python3
"""
PLM CI Policy Check - Protect critical infrastructure files from unauthorized changes.
"""

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Optional


AUTHORIZED_EMAIL = "networkarchetype@gmail.com"
AUTHORIZED_OWNER = "NetworkArchetype"

PROTECTED_PREFIXES = (
    ".githooks/",
    ".github/workflows/",
    "scripts/auto_version.py",
    "scripts/plm_security/",
)


@dataclass
class RepoInfo:
    owner_login: str
    owner_type: str


def _run_git(args: list[str]) -> str:
    result = subprocess.run(["git"] + args, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"git command failed: {' '.join(args)}")
    return result.stdout.strip()


def _get_commit_author_email(commit_sha: str) -> str:
    """Get the author email for a specific commit."""
    return _run_git(["log", "-1", "--format=%ae", commit_sha])


def _load_event(path: str) -> dict:
    with open(path, "r") as f:
        return json.load(f)


def _github_api_get(url: str, token: str) -> dict:
    import urllib.request
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"token {token}")
    req.add_header("Accept", "application/vnd.github.v3+json")
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())


def _repo_info(repo_full: str, token: str) -> RepoInfo:
    data = _github_api_get(f"https://api.github.com/repos/{repo_full}", token)
    owner = data.get("owner") or {}
    return RepoInfo(
        owner_login=str(owner.get("login") or ""),
        owner_type=str(owner.get("type") or "")
    )


def _changed_files(base: str, head: str) -> list[str]:
    out = _run_git(["diff", "--name-only", f"{base}..{head}"])
    return [line.strip() for line in out.splitlines() if line.strip()]


def _is_protected(path: str) -> bool:
    if path in PROTECTED_PREFIXES:
        return True
    for prefix in PROTECTED_PREFIXES:
        if prefix.endswith("/") and path.startswith(prefix):
            return True
    return False


def _actor_allowed(actor: str, repo: RepoInfo) -> bool:
    actor_l = actor.lower()
    # Check if actor is the authorized owner
    if repo.owner_login.lower() != AUTHORIZED_OWNER.lower():
        return False
    if actor_l != repo.owner_login.lower():
        return False
    return True


def _check_commit_email(commit_sha: str) -> bool:
    """Check if commit author email matches authorized email."""
    try:
        author_email = _get_commit_author_email(commit_sha)
        author_norm = author_email.strip().lower()
        authorized_norm = AUTHORIZED_EMAIL.strip().lower()

        # Allow exact configured email
        if author_norm == authorized_norm:
            return True

        # Allow GitHub web UI "noreply" email for the owner account
        # Common forms:
        # - NetworkArchetype@users.noreply.github.com
        # - 12345+NetworkArchetype@users.noreply.github.com
        owner = AUTHORIZED_OWNER.strip()
        noreply_re = re.compile(rf"^(\d+\+)?{re.escape(owner)}@users\.noreply\.github\.com$", re.IGNORECASE)
        return noreply_re.match(author_email.strip()) is not None
    except Exception as e:
        sys.stderr.write(f"Warning: Could not verify commit email: {e}\n")
        return False


def _pick_base_head(event: dict) -> tuple[Optional[str], Optional[str]]:
    if "pull_request" in event:
        pr = event.get("pull_request") or {}
        base = ((pr.get("base") or {}).get("sha") or "").strip()
        head = ((pr.get("head") or {}).get("sha") or "").strip()
        return (base or None, head or None)
    # push event
    base = str(event.get("before") or "").strip()
    head = str(event.get("after") or "").strip()
    return (base or None, head or None)


def main() -> int:
    repo_full = os.environ.get("GITHUB_REPOSITORY") or ""
    actor = os.environ.get("GITHUB_ACTOR") or ""
    token = os.environ.get("GITHUB_TOKEN") or ""
    event_path = os.environ.get("GITHUB_EVENT_PATH") or ""

    if not repo_full or not actor or not token or not event_path:
        sys.stderr.write("Missing required GitHub Actions environment variables.\n")
        return 2

    event = _load_event(event_path)
    base, head = _pick_base_head(event)
    if not base or not head:
        sys.stderr.write("Could not determine base/head SHAs for diff.\n")
        return 2

    files = _changed_files(base, head)
    protected = [p for p in files if _is_protected(p)]

    if not protected:
        print("No protected paths changed.")
        return 0

    repo = _repo_info(repo_full, token)
    if not repo.owner_login:
        sys.stderr.write("Could not determine repo owner.\n")
        return 2

    if _actor_allowed(actor, repo):
        # Also check commit author email
        if head and not _check_commit_email(head):
            sys.stderr.write(f"Denied: Commit author email does not match {AUTHORIZED_EMAIL}\n")
            sys.stderr.write("Only commits from networkarchetype@gmail.com are allowed.\n")
            return 1
        
        print(f"Protected paths changed by authorized actor '{actor}' with correct email.")
        for p in protected:
            print(f"  - {p}")
        return 0

    sys.stderr.write("Denied: protected paths were modified by a non-authorized actor.\n")
    sys.stderr.write(f"Actor: {actor}\n")
    sys.stderr.write(f"Repo owner: {repo.owner_login} (type={repo.owner_type})\n")
    sys.stderr.write(f"Required: Actor must be {AUTHORIZED_OWNER} with email {AUTHORIZED_EMAIL}\n")
    sys.stderr.write("Protected changes:\n")
    for p in protected:
        sys.stderr.write(f"  - {p}\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
