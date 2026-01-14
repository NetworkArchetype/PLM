#!/usr/bin/env python3
"""
PLM Commit Authorization Check
Ensures only networkarchetype@gmail.com can commit to the repository.
"""

import subprocess
import sys


AUTHORIZED_EMAIL = "networkarchetype@gmail.com"
AUTHORIZED_OWNER = "NetworkArchetype"


def get_git_config(key: str) -> str:
    """Get git config value."""
    result = subprocess.run(
        ["git", "config", "--get", key],
        capture_output=True,
        text=True,
        check=False
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def check_author_authorization() -> bool:
    """Check if current git user is authorized to commit."""
    author_email = get_git_config("user.email")
    author_name = get_git_config("user.name")
    
    if not author_email:
        print("❌ Error: Git user.email not configured", file=sys.stderr)
        print(f"   Run: git config user.email '{AUTHORIZED_EMAIL}'", file=sys.stderr)
        return False
    
    if author_email != AUTHORIZED_EMAIL:
        print(f"❌ Unauthorized commit email: {author_email}", file=sys.stderr)
        print(f"   Only {AUTHORIZED_EMAIL} can commit to this repository", file=sys.stderr)
        print(f"   Current author: {author_name} <{author_email}>", file=sys.stderr)
        print(f"\n   To authorize commits, run:", file=sys.stderr)
        print(f"   git config user.email '{AUTHORIZED_EMAIL}'", file=sys.stderr)
        return False
    
    print(f"✓ Authorized: {author_name} <{author_email}>")
    return True


def main() -> int:
    """Main entry point."""
    if not check_author_authorization():
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
