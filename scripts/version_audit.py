#!/usr/bin/env python3
"""
PLM Version Audit System
Validates version tracking, sequence integrity, and tag compliance.
"""

import json
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Tuple


@dataclass
class VersionInfo:
    """Represents a version with its metadata."""
    tag: str
    major: int
    minor: int
    patch: int
    commit_hash: str
    commit_date: str


@dataclass
class AuditResult:
    """Results of version auditing."""
    version_sequence_valid: bool
    missing_versions: List[str]
    duplicate_versions: List[str]
    total_versions: int
    last_version: Optional[str]
    first_version: Optional[str]
    total_commits: int
    audit_timestamp: str
    repository_path: str
    issues: List[str]
    recommendations: List[str]


class VersionAuditor:
    """PLM version auditing system."""

    def __init__(self, repo_path: Optional[Path] = None):
        self.repo_path = repo_path or Path.cwd()
        self.versions: List[VersionInfo] = []

    def is_git_repository(self) -> bool:
        try:
            subprocess.run(
                ["git", "rev-parse", "--git-dir"],
                cwd=self.repo_path,
                capture_output=True,
                check=True
            )
            return True
        except:
            return False

    def collect_version_data(self) -> List[VersionInfo]:
        """Collect all version information from git tags."""
        result = subprocess.run(
            ["git", "tag", "-l", "v*", "--sort=-version:refname"],
            cwd=self.repo_path,
            capture_output=True,
            text=True,
            check=False
        )

        versions = []
        for tag in result.stdout.splitlines():
            tag = tag.strip()
            if not tag:
                continue

            # Parse version
            match = re.match(r"^v?(\d+)\.(\d+)\.(\d+)$", tag)
            if not match:
                continue

            major, minor, patch = int(match.group(1)), int(match.group(2)), int(match.group(3))

            # Get commit info
            commit_result = subprocess.run(
                ["git", "rev-list", "-n", "1", tag],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=False
            )
            commit_hash = commit_result.stdout.strip()

            date_result = subprocess.run(
                ["git", "log", "-1", "--format=%ci", tag],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=False
            )
            commit_date = date_result.stdout.strip()

            versions.append(VersionInfo(
                tag=tag,
                major=major,
                minor=minor,
                patch=patch,
                commit_hash=commit_hash,
                commit_date=commit_date
            ))

        return versions

    def validate_version_sequence(self, versions: List[VersionInfo]) -> Tuple[bool, List[str]]:
        """Validate version sequence continuity."""
        if not versions:
            return True, []

        issues = []
        sorted_versions = sorted(versions, key=lambda v: (v.major, v.minor, v.patch))

        for i, v in enumerate(sorted_versions[:-1]):
            next_v = sorted_versions[i + 1]
            if v.major == next_v.major and v.minor == next_v.minor:
                if next_v.patch != v.patch + 1:
                    issues.append(f"Gap in patch sequence: {v.tag} -> {next_v.tag}")

        return len(issues) == 0, issues

    def find_duplicate_versions(self, versions: List[VersionInfo]) -> List[str]:
        """Find duplicate version tags."""
        seen = set()
        duplicates = []
        for v in versions:
            key = (v.major, v.minor, v.patch)
            if key in seen:
                duplicates.append(v.tag)
            seen.add(key)
        return duplicates

    def get_total_commits(self) -> int:
        """Get total number of commits."""
        result = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"],
            cwd=self.repo_path,
            capture_output=True,
            text=True,
            check=False
        )
        return int(result.stdout.strip()) if result.returncode == 0 else 0

    def audit_versions(self) -> AuditResult:
        """Perform complete version audit."""
        if not self.is_git_repository():
            raise RuntimeError(f"Path {self.repo_path} is not a git repository")

        self.versions = self.collect_version_data()
        sequence_valid, sequence_issues = self.validate_version_sequence(self.versions)
        duplicate_versions = self.find_duplicate_versions(self.versions)
        total_commits = self.get_total_commits()

        issues = sequence_issues.copy()
        if duplicate_versions:
            issues.extend([f"Duplicate version: {v}" for v in duplicate_versions])

        recommendations = []
        if not self.versions:
            recommendations.append("Initialize version tracking by creating the first version tag")
        if not sequence_valid:
            recommendations.append("Fix version sequence gaps for proper semantic versioning")

        return AuditResult(
            version_sequence_valid=sequence_valid,
            missing_versions=[],
            duplicate_versions=duplicate_versions,
            total_versions=len(self.versions),
            last_version=self.versions[0].tag if self.versions else None,
            first_version=self.versions[-1].tag if self.versions else None,
            total_commits=total_commits,
            audit_timestamp=datetime.now().isoformat(),
            repository_path=str(self.repo_path),
            issues=issues,
            recommendations=recommendations
        )

    def export_audit_report(self, output_file: Optional[str] = None) -> str:
        """Export audit results to JSON."""
        result = self.audit_versions()
        report = asdict(result)
        json_str = json.dumps(report, indent=2)
        
        if output_file:
            Path(output_file).write_text(json_str)
        
        return json_str


def main():
    """Command-line interface for version auditing."""
    auditor = VersionAuditor()
    
    try:
        result = auditor.audit_versions()
        print(json.dumps(asdict(result), indent=2))
        
        if result.issues:
            print("\n⚠️  Issues found:", file=sys.stderr)
            for issue in result.issues:
                print(f"  - {issue}", file=sys.stderr)
            return 1
        
        print("\n✓ Version audit passed")
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
