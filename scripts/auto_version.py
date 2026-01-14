#!/usr/bin/env python3
"""
Auto version management for PLM.
Handles automatic version incrementing with git integration.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple


def _run_git(args: list[str], cwd: Path) -> Tuple[int, str]:
    try:
        result = subprocess.run(
            ["git"] + args,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode, result.stdout.strip()
    except Exception as e:
        return 1, str(e)


def _read_version_file(repo_root: Path) -> Optional[str]:
    version_file = repo_root / "VERSION"
    if not version_file.exists():
        return None
    content = version_file.read_text().strip()
    # Normalize: strip 'v' prefix if present
    if content.startswith("v"):
        content = content[1:]
    return content


def _write_version_file(repo_root: Path, version: str) -> None:
    version_file = repo_root / "VERSION"
    # Write with 'v' prefix
    version_file.write_text(f"v{version}\n")


def _get_latest_version_tag(repo_root: Path) -> Optional[Tuple[int, int, int]]:
    code, out = _run_git(["tag", "-l", "v*"], repo_root)
    if code != 0 or not out:
        return None

    versions = []
    for tag in out.splitlines():
        match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)$", tag.strip())
        if match:
            versions.append((int(match.group(1)), int(match.group(2)), int(match.group(3))))

    return max(versions) if versions else None


def _bump_version(version: Tuple[int, int, int], bump_type: str) -> Tuple[int, int, int]:
    major, minor, patch = version
    if bump_type == "major":
        return (major + 1, 0, 0)
    elif bump_type == "minor":
        return (major, minor + 1, 0)
    else:  # patch
        return (major, minor, patch + 1)


def _sync_version_to_files(repo_root: Path, version: str) -> None:
    """Sync version to plm_formalized/__init__.py"""
    init_file = repo_root / "Code_core_3" / "plm-formalized" / "plm_formalized" / "__init__.py"
    if not init_file.exists():
        return

    content = init_file.read_text()
    # Replace __version__ line
    new_content = re.sub(
        r'__version__\s*=\s*["\'][^"\']*["\']',
        f'__version__ = "{version}"',
        content
    )
    init_file.write_text(new_content)


def _maybe_stage_version_files(repo_root: Path) -> None:
    try:
        subprocess.run(
            ["git", "add", "VERSION", "Code_core_3/plm-formalized/plm_formalized/__init__.py"],
            cwd=repo_root,
            check=False,
            capture_output=True,
        )
    except Exception:
        pass


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="PLM auto version management")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--bump-patch", action="store_true", help="Bump patch version (default)")
    group.add_argument("--bump-minor", action="store_true", help="Bump minor version")
    group.add_argument("--bump-major", action="store_true", help="Bump major version")
    group.add_argument("--sync-from-version", action="store_true", help="Sync from VERSION file without bumping")
    parser.add_argument("--stage", action="store_true", help="Stage version files (git add)")
    parser.add_argument("--pre-commit", action="store_true", help="Pre-commit hook mode")

    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parents[1]

    # Determine bump type
    bump_type = "patch"  # default
    if args.bump_minor:
        bump_type = "minor"
    elif args.bump_major:
        bump_type = "major"

    # Get current version from tags
    latest_tag_version = _get_latest_version_tag(repo_root)
    if latest_tag_version is None:
        # No tags yet, start at 0.1.0
        target_version = (0, 1, 0)
    elif args.sync_from_version:
        # Read from VERSION file
        current_version = _read_version_file(repo_root)
        if current_version:
            match = re.match(r"^(\d+)\.(\d+)\.(\d+)$", current_version)
            if match:
                target_version = (int(match.group(1)), int(match.group(2)), int(match.group(3)))
            else:
                print(f"Invalid VERSION format: {current_version}")
                return 1
        else:
            target_version = (0, 1, 0)
    else:
        # Bump from latest tag
        target_version = _bump_version(latest_tag_version, bump_type)

    target_version_str = f"{target_version[0]}.{target_version[1]}.{target_version[2]}"

    # Check if already set
    current_version_file = _read_version_file(repo_root)
    if current_version_file == target_version_str and not args.sync_from_version:
        if args.stage:
            _maybe_stage_version_files(repo_root)
        return 0

    # Write VERSION
    _write_version_file(repo_root, target_version_str)

    # Sync to other files
    _sync_version_to_files(repo_root, target_version_str)

    if args.stage:
        _maybe_stage_version_files(repo_root)

    print(f"Version bumped to v{target_version_str}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
