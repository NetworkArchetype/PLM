"""Repository secret scanner.

Outputs a JSON report that includes file path + line number + rule name.
It intentionally does NOT output matched secret values.

Usage (from repo root):
  python scripts/security_secret_scan.py --out bak/secret-scan-report.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Finding:
    rule: str
    file: str
    line: int
    col: int
    match_sha256: str


DEFAULT_EXCLUDE_DIRS = {
    ".git",
    "node_modules",
    "venv",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
}

DEFAULT_EXCLUDE_EXTS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".bmp",
    ".ico",
    ".pdf",
    ".zip",
    ".7z",
    ".tar",
    ".gz",
    ".tgz",
    ".rar",
    ".exe",
    ".dll",
    ".pdb",
    ".so",
    ".dylib",
    ".bin",
    ".dat",
    ".db",
    ".sqlite",
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".wav",
    ".mp3",
    ".vsdx",
}


RULES: list[tuple[str, re.Pattern[str]]] = [
    (
        "PrivateKeyBlock",
        re.compile(r"-----BEGIN (?:OPENSSH|RSA|EC|DSA|PRIVATE KEY)-----"),
    ),
    ("GitHubTokenClassic", re.compile(r"\bghp_[A-Za-z0-9]{36}\b")),
    ("GitHubTokenFineGrained", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{80,}\b")),
    ("AWSAccessKeyId", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("GoogleApiKey", re.compile(r"\bAIza[0-9A-Za-z\-_]{35}\b")),
    ("SlackToken", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("BearerToken", re.compile(r"\bBearer\s+[A-Za-z0-9\-_.=]{20,}\b")),
    (
        "AzureStorageConnString",
        re.compile(
            r"DefaultEndpointsProtocol\s*=\s*https?;.*AccountName\s*=\s*[^;]+;.*AccountKey\s*=\s*[^;]+",
            re.IGNORECASE,
        ),
    ),
    (
        "GenericPasswordAssign",
        re.compile(
            r"(?i)\b(password|passwd|pwd)\b\s*[:=]\s*[^\s\"\'`;]{6,}"
        ),
    ),
    (
        "GenericApiKeyAssign",
        re.compile(
            r"(?i)\b(api[_-]?key|secret|token)\b\s*[:=]\s*[^\s\"\'`;]{8,}"
        ),
    ),
]


def iter_files(
    root: Path,
    exclude_dirs: set[str],
    exclude_exts: set[str],
) -> Iterable[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        dp = Path(dirpath)
        # prune excluded directories
        dirnames[:] = [
            d
            for d in dirnames
            if d not in exclude_dirs and not (dp / d).name.startswith(".git")
        ]
        for name in filenames:
            p = dp / name
            if p.suffix.lower() in exclude_exts:
                continue
            yield p


def sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()


def scan_file(path: Path, root: Path, max_bytes: int) -> list[Finding]:
    try:
        if path.stat().st_size > max_bytes:
            return []
        data = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return []

    findings: list[Finding] = []
    rel = str(path.relative_to(root)).replace("\\", "/")
    for line_no, line in enumerate(data.splitlines(), start=1):
        for rule_name, pat in RULES:
            for m in pat.finditer(line):
                findings.append(
                    Finding(
                        rule=rule_name,
                        file=rel,
                        line=line_no,
                        col=(m.start() + 1),
                        match_sha256=sha256_hex(m.group(0)),
                    )
                )
    return findings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".", help="Repo root")
    ap.add_argument("--out", required=True, help="Output JSON path")
    ap.add_argument(
        "--max-bytes",
        type=int,
        default=5_000_000,
        help="Skip files larger than this (default: 5MB)",
    )
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out_path = (root / args.out).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    findings: list[Finding] = []
    for p in iter_files(root, DEFAULT_EXCLUDE_DIRS, DEFAULT_EXCLUDE_EXTS):
        findings.extend(scan_file(p, root, args.max_bytes))

    findings_sorted = sorted(findings, key=lambda f: (f.rule, f.file, f.line, f.col))
    out = {
        "root": str(root),
        "total_findings": len(findings_sorted),
        "rules": [name for name, _ in RULES],
        "findings": [asdict(f) for f in findings_sorted],
    }
    out_path.write_text(json.dumps(out, indent=2), encoding="utf-8")

    # concise stdout summary (safe)
    print(f"Wrote: {out_path}")
    print(f"TOTAL_FINDINGS={len(findings_sorted)}")

    # top files summary
    by_file: dict[str, int] = {}
    for f in findings_sorted:
        by_file[f.file] = by_file.get(f.file, 0) + 1
    top = sorted(by_file.items(), key=lambda kv: kv[1], reverse=True)[:20]
    if top:
        print("TOP_FILES:")
        for file, count in top:
            print(f"  {count:4d}  {file}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
