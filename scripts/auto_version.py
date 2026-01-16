#!/usr/bin/env python3
"""
Auto version management for PLM.
Handles automatic version incrementing with git integration.
"""

import argparse
import re
import subprocess
import sys
import os
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
    return content


def _write_version_file(repo_root: Path, version: str) -> None:
    version_file = repo_root / "VERSION"
    version_file.write_text(f"{version}\n")


_VERSION_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")


def _parse_version(version: str) -> Optional[Tuple[int, int, int]]:
    v = version.strip()
    if not v:
        return None
    m = _VERSION_RE.match(v)
    if not m:
        return None
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))


def _format_version(major: int, minor: int, patch: int) -> str:
    # Match damoclese-sword canonical format: v{major}.{minor}.{patch:06d}
    return f"v{major}.{minor}.{patch:06d}"


def _get_latest_version_tag(repo_root: Path) -> Optional[Tuple[int, int, int]]:
    # Avoid relying on git's version sorting because leading zeros can behave unexpectedly.
    code, out = _run_git(["tag", "-l", "v*"], repo_root)
    if code != 0 or not out:
        return None

    versions = []
    for tag in out.splitlines():
        parsed = _parse_version(tag.strip())
        if parsed:
            versions.append(parsed)

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


def _git_staged_paths(repo_root: Path) -> set[str]:
    code, out = _run_git(["diff", "--cached", "--name-only"], repo_root)
    if code != 0 or not out:
        return set()
    return {line.strip() for line in out.splitlines() if line.strip()}


def _version_without_v(version_with_v: str) -> str:
    v = version_with_v.strip()
    return v[1:] if v.startswith("v") else v


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

    # Mirror damoclese-sword bypass environment variables.
    if os.environ.get("DS_SKIP_VERSION_BUMP") == "1":
        if args.stage:
            _maybe_stage_version_files(repo_root)
        return 0

    # Determine bump type
    bump_type = "patch"  # default
    if args.bump_minor:
        bump_type = "minor"
    elif args.bump_major:
        bump_type = "major"

    latest_tag_version = _get_latest_version_tag(repo_root)
    staged_paths = _git_staged_paths(repo_root) if args.pre_commit else set()
    version_file_path = "VERSION"

    # damoclese-sword behavior: in --pre-commit mode, if VERSION is already staged,
    # treat it as an explicit version set and only canonicalize/sync.
    if args.pre_commit and version_file_path in staged_paths:
        raw_version = _read_version_file(repo_root)
        parsed = _parse_version(raw_version or "")
        if not parsed:
            print(f"Invalid VERSION format: {raw_version}", file=sys.stderr)
            return 1
        if latest_tag_version and parsed < latest_tag_version:
            print(
                f"Refusing to downgrade VERSION behind latest tag: {raw_version} < {_format_version(*latest_tag_version)}",
                file=sys.stderr,
            )
            return 1
        target_version_tuple = parsed
    elif args.sync_from_version:
        raw_version = _read_version_file(repo_root)
        parsed = _parse_version(raw_version or "")
        if not parsed:
            print(f"Invalid VERSION format: {raw_version}", file=sys.stderr)
            return 1
        if latest_tag_version and parsed < latest_tag_version:
            print(
                f"Refusing to downgrade VERSION behind latest tag: {raw_version} < {_format_version(*latest_tag_version)}",
                file=sys.stderr,
            )
            return 1
        target_version_tuple = parsed
    else:
        if latest_tag_version is None:
            base_version = (0, 1, 0)
        else:
            base_version = latest_tag_version
        target_version_tuple = _bump_version(base_version, bump_type)

    target_version = _format_version(*target_version_tuple)
    target_version_no_v = _version_without_v(target_version)

    # Write VERSION (canonical)
    _write_version_file(repo_root, target_version)

    # Sync to other files (canonical without leading 'v')
    _sync_version_to_files(repo_root, target_version_no_v)

    if args.stage:
        _maybe_stage_version_files(repo_root)

    print(f"Version set to {target_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
