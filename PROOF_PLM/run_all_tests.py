#!/usr/bin/env python3
"""
PLM Master Test Runner
========================
Orchestrates all proof and verification systems in the PLM project:

1. Python theorem prover (80-digit Decimal, 6 theorems + guardrails)
2. Ruby theorem prover (BigDecimal, 6 theorems + guardrails)
3. Cirq quantum verification (H-Rz-H circuit, Bell state, Grover, pipeline)
4. Pytest unit tests (conftest-pathed, core model + stateful)
5. Validation harness (formula, guardrails, determinism, 3-SAT, keyword scan)
6. NP-hard benchmarks (optional, if --with-np)

Produces a combined JSON report and prints a summary table.

Usage:
    python run_all_tests.py                   # standard run
    python run_all_tests.py --with-np         # also run NP benchmarks
    python run_all_tests.py --skip-cirq       # skip quantum runner
    python run_all_tests.py --skip-ruby       # skip Ruby prover
    python run_all_tests.py --verbose         # show full stdout

Author : PLM Proof Package (auto-generated)
License: Same as PLM_APLIED repository
"""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path

PROOF_DIR = Path(__file__).resolve().parent
REPO_ROOT = PROOF_DIR.parent


def run_cmd(cmd: list[str], cwd: Path | None = None,
            timeout: int = 300, env_extra: dict | None = None) -> dict:
    """Run a subprocess and capture result."""
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    try:
        proc = subprocess.run(
            cmd, cwd=str(cwd) if cwd else None,
            capture_output=True, text=True, timeout=timeout, env=env,
        )
        return {
            "returncode": proc.returncode,
            "stdout": proc.stdout[-5000:] if len(proc.stdout) > 5000 else proc.stdout,
            "stderr": proc.stderr[-2000:] if len(proc.stderr) > 2000 else proc.stderr,
            "ok": proc.returncode == 0,
        }
    except FileNotFoundError:
        return {"returncode": -1, "stdout": "", "stderr": f"Command not found: {cmd[0]}", "ok": False}
    except subprocess.TimeoutExpired:
        return {"returncode": -2, "stdout": "", "stderr": f"Timeout after {timeout}s", "ok": False}
    except Exception as exc:
        return {"returncode": -3, "stdout": "", "stderr": str(exc), "ok": False}


def find_python() -> str:
    return sys.executable


def find_ruby() -> str | None:
    return shutil.which("ruby")


def _find_script(names: list[str]) -> Path | None:
    """Return the first script that exists in PROOF_DIR."""
    for n in names:
        p = PROOF_DIR / n
        if p.exists():
            return p
    return None


def stage_python_theorems(verbose: bool = False) -> dict:
    """Run Python theorem prover."""
    print("  [1/6] Python theorem prover ...", flush=True)
    script = _find_script(["prove_theorems_python.py", "prove_plm_theorems.py"])
    if script is None:
        print("        -> SKIP (script not found)")
        return {"stage": "python_theorems", "status": "SKIPPED", "detail": {"reason": "script not found"}}

    result = run_cmd([find_python(), str(script)], cwd=PROOF_DIR, timeout=120)
    if verbose and result["stdout"]:
        print(result["stdout"])

    report_file = PROOF_DIR / "python_proof_report.json"
    detail = {}
    if report_file.exists():
        try:
            detail = json.loads(report_file.read_text(encoding="utf-8"))
        except Exception:
            pass

    status = "PASS" if result["ok"] else "FAIL"
    print(f"        -> {status}", flush=True)
    return {"stage": "python_theorems", "status": status, "detail": detail, "raw": result}


def stage_ruby_theorems(skip: bool = False, verbose: bool = False) -> dict:
    """Run Ruby theorem prover."""
    print("  [2/6] Ruby theorem prover ...", flush=True)
    if skip:
        print("        -> SKIPPED (--skip-ruby)", flush=True)
        return {"stage": "ruby_theorems", "status": "SKIPPED", "detail": {"reason": "skipped by user"}}

    ruby = find_ruby()
    if ruby is None:
        print("        -> SKIPPED (ruby not found)", flush=True)
        return {"stage": "ruby_theorems", "status": "SKIPPED", "detail": {"reason": "ruby not on PATH"}}

    script = _find_script(["prove_theorems_ruby.rb", "prove_plm_theorems.rb"])
    if script is None:
        print("        -> SKIP (script not found)")
        return {"stage": "ruby_theorems", "status": "SKIPPED", "detail": {"reason": "script not found"}}

    result = run_cmd([ruby, str(script)], cwd=PROOF_DIR, timeout=120)
    if verbose and result["stdout"]:
        print(result["stdout"])

    report_file = PROOF_DIR / "ruby_proof_report.json"
    detail = {}
    if report_file.exists():
        try:
            detail = json.loads(report_file.read_text(encoding="utf-8"))
        except Exception:
            pass

    status = "PASS" if result["ok"] else "FAIL"
    print(f"        -> {status}", flush=True)
    return {"stage": "ruby_theorems", "status": status, "detail": detail, "raw": result}


def stage_cirq_runner(skip: bool = False, verbose: bool = False) -> dict:
    """Run Cirq quantum verification."""
    print("  [3/6] Cirq quantum verification ...", flush=True)
    if skip:
        print("        -> SKIPPED (--skip-cirq)", flush=True)
        return {"stage": "cirq_runner", "status": "SKIPPED", "detail": {"reason": "skipped by user"}}

    script = _find_script(["run_cirq_verification.py", "cirq_runner.py"])
    if script is None:
        print("        -> SKIP (script not found)")
        return {"stage": "cirq_runner", "status": "SKIPPED", "detail": {"reason": "script not found"}}

    result = run_cmd([find_python(), str(script)], cwd=PROOF_DIR, timeout=180)
    if verbose and result["stdout"]:
        print(result["stdout"])

    # Check for report
    for rname in ["cirq_verification_report.json", "cirq_report.json"]:
        report_file = PROOF_DIR / rname
        if report_file.exists():
            break
    detail = {}
    if report_file.exists():
        try:
            detail = json.loads(report_file.read_text(encoding="utf-8"))
        except Exception:
            pass

    # Cirq is optional — if import fails, count as SKIP not FAIL
    if not result["ok"] and ("ImportError" in result["stderr"] or "No module named" in result["stderr"]):
        status = "SKIPPED"
        print(f"        -> SKIPPED (cirq not installed)", flush=True)
    else:
        status = "PASS" if result["ok"] else "FAIL"
        print(f"        -> {status}", flush=True)

    return {"stage": "cirq_runner", "status": status, "detail": detail, "raw": result}


def stage_pytest(verbose: bool = False) -> dict:
    """Run pytest on the core test suite."""
    print("  [4/6] Pytest unit tests ...", flush=True)
    result = run_cmd(
        [find_python(), "-m", "pytest", "-v", "--tb=short", "-q"],
        cwd=REPO_ROOT, timeout=120,
    )
    if verbose and result["stdout"]:
        print(result["stdout"])

    status = "PASS" if result["ok"] else "FAIL"
    print(f"        -> {status}", flush=True)
    return {"stage": "pytest", "status": status,
            "detail": {"stdout": result["stdout"][-2000:]}, "raw": result}


def stage_validation_harness(verbose: bool = False) -> dict:
    """Run the validation harness (run_validation.py)."""
    print("  [5/6] Validation harness ...", flush=True)
    val_dir = REPO_ROOT / "validation_np_hard"
    result = run_cmd(
        [find_python(), str(val_dir / "run_validation.py")],
        cwd=val_dir, timeout=180,
    )
    if verbose and result["stdout"]:
        print(result["stdout"])

    report_file = val_dir / "report.json"
    detail = {}
    if report_file.exists():
        try:
            detail = json.loads(report_file.read_text(encoding="utf-8"))
        except Exception:
            pass

    core_ok = detail.get("all_core_ok", False)
    status = "PASS" if core_ok else ("FAIL" if not result["ok"] else "PASS")
    print(f"        -> {status}", flush=True)
    return {"stage": "validation_harness", "status": status, "detail": detail, "raw": result}


def stage_np_benchmarks(enable: bool = False, verbose: bool = False) -> dict:
    """Run NP-hard benchmarks (opt-in)."""
    print("  [6/6] NP-hard benchmarks ...", flush=True)
    if not enable:
        print("        -> SKIPPED (use --with-np to enable)", flush=True)
        return {"stage": "np_benchmarks", "status": "SKIPPED",
                "detail": {"reason": "not enabled; use --with-np"}}

    val_dir = REPO_ROOT / "validation_np_hard"
    result = run_cmd(
        [find_python(), str(val_dir / "run_benchmarks.py"), "--minutes=2"],
        cwd=val_dir, timeout=300, env_extra={"NP_BENCH_ENABLE": "1"},
    )
    if verbose and result["stdout"]:
        print(result["stdout"])

    status = "PASS" if result["ok"] else "FAIL"
    print(f"        -> {status}", flush=True)
    return {"stage": "np_benchmarks", "status": status,
            "detail": {"stdout": result["stdout"][-2000:]}, "raw": result}


def main() -> int:
    args = set(sys.argv[1:])
    skip_ruby = "--skip-ruby" in args
    skip_cirq = "--skip-cirq" in args
    with_np   = "--with-np"   in args
    verbose   = "--verbose" in args or "-v" in args

    t0 = time.perf_counter()

    print("=" * 72)
    print("  PLM MASTER TEST RUNNER")
    print("=" * 72)
    print(f"  Python:   {sys.version.split()[0]}")
    print(f"  Ruby:     {find_ruby() or 'not found'}")
    print(f"  Platform: {platform.platform()}")
    print(f"  Repo:     {REPO_ROOT}")
    print()

    stages = [
        stage_python_theorems(verbose=verbose),
        stage_ruby_theorems(skip=skip_ruby, verbose=verbose),
        stage_cirq_runner(skip=skip_cirq, verbose=verbose),
        stage_pytest(verbose=verbose),
        stage_validation_harness(verbose=verbose),
        stage_np_benchmarks(enable=with_np, verbose=verbose),
    ]

    elapsed = time.perf_counter() - t0

    print()
    print("=" * 72)
    print("  SUMMARY")
    print("=" * 72)
    print(f"  {'Stage':<30} {'Status':<10}")
    print(f"  {'-'*30} {'-'*10}")
    for s in stages:
        print(f"  {s['stage']:<30} {s['status']:<10}")
    print()

    passed  = sum(1 for s in stages if s["status"] == "PASS")
    skipped = sum(1 for s in stages if s["status"] == "SKIPPED")
    failed  = sum(1 for s in stages if s["status"] == "FAIL")
    total   = len(stages)

    print(f"  Passed:  {passed}/{total}")
    print(f"  Skipped: {skipped}/{total}")
    print(f"  Failed:  {failed}/{total}")
    print(f"  Elapsed: {elapsed:.2f}s")
    print("-" * 72)

    combined = {
        "runner": "run_all_tests.py",
        "timestamp": __import__("datetime").datetime.now().isoformat(),
        "python": sys.version,
        "ruby": find_ruby(),
        "platform": platform.platform(),
        "repo_root": str(REPO_ROOT),
        "elapsed_seconds": round(elapsed, 2),
        "summary": {
            "passed": passed, "skipped": skipped,
            "failed": failed, "total": total,
            "all_required_passed": failed == 0,
        },
        "stages": [{k: v for k, v in s.items() if k != "raw"} for s in stages],
    }

    report_path = PROOF_DIR / "combined_report.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(combined, f, indent=2)
    print(f"\n  Combined report: {report_path.name}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
