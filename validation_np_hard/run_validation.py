from __future__ import annotations

import json
import math
import os
import sys
import traceback
from dataclasses import asdict, dataclass
from decimal import Decimal
from pathlib import Path
from typing import Any, Dict, List, Tuple

REPO_ROOT = Path(__file__).resolve().parents[1]


@dataclass
class CheckResult:
    name: str
    ok: bool
    details: Dict[str, Any]


def _import_plm() -> Tuple[Any, Any, Any]:
    """Import the in-repo PLM package without altering project code.

    This harness assumes PLM is installed editable (recommended), or that the repo
    root is on sys.path. As a safety net for local runs, we add the package root.
    """
    pkg_root = REPO_ROOT / "Code_core_3" / "plm-formalized"
    if str(pkg_root) not in sys.path:
        sys.path.insert(0, str(pkg_root))

    import plm_formalized  # type: ignore
    from plm_formalized.model import PLMInputs, plm_secret_value  # type: ignore
    from plm_formalized.stateful import PLMState, StatefulPLM, update_x_linear  # type: ignore

    return plm_formalized, (PLMInputs, plm_secret_value), (PLMState, StatefulPLM, update_x_linear)


def check_plm_formula() -> CheckResult:
    _, (PLMInputs, plm_secret_value), _ = _import_plm()

    pi = Decimal(str(math.pi))
    lam = Decimal("1.6180339887498948482")
    mu = Decimal("2.7182818284590452353")

    inp = PLMInputs(
        pi=pi,
        lam=lam,
        mu=mu,
        x=42,
        public_hash_hex="abcdef1234567890",
        block_size=128,
        crc_decimal=12345,
    )

    # Independent expected computation using the documented formula.
    y = Decimal(int("abcdef1234567890", 16))
    c = Decimal(128 + 12345)
    expected = ((pi * y) * (lam * Decimal(42))) / (mu * c)

    got = plm_secret_value(inp)

    ok = got == expected
    return CheckResult(
        name="plm_formula_exact_decimal",
        ok=ok,
        details={
            "expected": str(expected),
            "got": str(got),
        },
    )


def check_plm_guardrails() -> List[CheckResult]:
    _, (PLMInputs, plm_secret_value), _ = _import_plm()

    pi = Decimal("3.14")
    lam = Decimal("1.61")

    results: List[CheckResult] = []

    # mu cannot be 0
    try:
        inp = PLMInputs(pi=pi, lam=lam, mu=Decimal(0), x=1, public_hash_hex="aa", block_size=1, crc_decimal=1)
        _ = plm_secret_value(inp)
        results.append(CheckResult("mu_nonzero", False, {"error": "expected ZeroDivisionError"}))
    except ZeroDivisionError:
        results.append(CheckResult("mu_nonzero", True, {}))

    # C must be positive
    try:
        inp = PLMInputs(pi=pi, lam=lam, mu=Decimal(1), x=1, public_hash_hex="aa", block_size=0, crc_decimal=0)
        _ = plm_secret_value(inp)
        results.append(CheckResult("c_positive", False, {"error": "expected ValueError"}))
    except ValueError:
        results.append(CheckResult("c_positive", True, {}))

    # Hex must be valid
    try:
        inp = PLMInputs(pi=pi, lam=lam, mu=Decimal(1), x=1, public_hash_hex="not-hex", block_size=1, crc_decimal=1)
        _ = plm_secret_value(inp)
        results.append(CheckResult("hex_valid", False, {"error": "expected exception for invalid hex"}))
    except Exception:
        results.append(CheckResult("hex_valid", True, {}))

    return results


def check_stateful_plm_determinism() -> CheckResult:
    _, (PLMInputs, _), (PLMState, StatefulPLM, update_x_linear) = _import_plm()

    pi = Decimal("3.141592653589793")
    lam = Decimal("1.618033988749895")
    mu = Decimal("2.718281828459045")

    inp = PLMInputs(pi=pi, lam=lam, mu=mu, x=1, public_hash_hex="0f", block_size=128, crc_decimal=1)
    st0 = PLMState(t=0, inputs=inp)

    m1 = StatefulPLM(st0, update_x_linear(1))
    m2 = StatefulPLM(st0, update_x_linear(1))

    seq1 = [str(m1.value())] + [str(m1.step()) for _ in range(5)]
    seq2 = [str(m2.value())] + [str(m2.step()) for _ in range(5)]

    return CheckResult(
        name="stateful_determinism",
        ok=seq1 == seq2,
        details={"seq1": seq1, "seq2": seq2},
    )


def capability_scan_keywords() -> CheckResult:
    """Scan repo text for explicit solver keywords.

    This is intentionally conservative: it reports matches and file locations,
    but does not claim functionality.
    """
    # Keep these relatively specific to reduce false positives in docs and vendor code.
    keywords = [
        "NP-hard",
        "np-hard",
        "3-SAT",
        "satisfiability",
        "sat solver",
        "knapsack",
        "subset sum",
        "traveling salesman",
        "tsp solver",
        "clique",
        "vertex cover",
        "hamiltonian",
        "ilp",
        "integer programming",
        "integer linear",
        "branch and bound",
        "simulated annealing",
        "genetic algorithm",
    ]

    hits: List[Dict[str, Any]] = []

    IGNORE_DIRS = {
        ".git",
        ".pytest_cache",
        "__pycache__",
        "bak",
        "plm_bak",
        "node_modules",
        "venv",
        ".venv",
        "site-packages",
        "dist",
        "build",
    }

    def iter_files() -> List[Path]:
        out: List[Path] = []
        # Prefer code-first scanning; avoid recursive scanning of repo root.
        for base in (
            REPO_ROOT / "Code_core_3",
            REPO_ROOT / "code-core-3",
            REPO_ROOT / "scripts",
            REPO_ROOT / "Deploy",
            REPO_ROOT / "docs",
        ):
            if not base.exists():
                continue
            for pat in ("**/*.py", "**/*.md", "**/*.txt"):
                out.extend(base.glob(pat))

        # Scan only top-level text/code in the repo root.
        for pat in ("*.py", "*.md", "*.txt", "*.rb"):
            out.extend(REPO_ROOT.glob(pat))

        # De-dupe while preserving order
        seen: set[Path] = set()
        uniq: List[Path] = []
        for p in out:
            if p in seen:
                continue
            seen.add(p)
            uniq.append(p)
        return uniq

    # Hard cap to keep this tool responsive.
    max_bytes = 512 * 1024

    # Hard cap to keep this tool responsive and reports readable.
    max_hits = 200
    truncated = False
    scanned = 0
    skipped = 0

    for fp in iter_files():
        parts_lower = {p.lower() for p in fp.parts}
        if any(d in parts_lower for d in IGNORE_DIRS):
            skipped += 1
            continue
        rel = str(fp.relative_to(REPO_ROOT)).replace("\\", "/")
        if rel.startswith("docs/") and ("chat" in rel or "transcript" in rel or rel.endswith(".txt")):
            # These are often large conversation logs.
            skipped += 1
            continue
        try:
            try:
                if fp.stat().st_size > max_bytes:
                    skipped += 1
                    continue
            except OSError:
                skipped += 1
                continue
            text = fp.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            skipped += 1
            continue
        scanned += 1
        lower = text.lower()
        for kw in keywords:
            if kw.lower() in lower:
                hits.append({"file": str(fp.relative_to(REPO_ROOT)), "keyword": kw})
                if len(hits) >= max_hits:
                    truncated = True
                break

        if truncated:
            break

    return CheckResult(
        name="capability_scan_keywords",
        ok=True,
        details={
            "hits": hits,
            "hit_count": len(hits),
            "hit_truncated": truncated,
            "scanned_file_count": scanned,
            "skipped_file_count": skipped,
        },
    )


def check_quantum_np_hard_demo() -> List[CheckResult]:
    """Optional: run small quantum demo(s) if dependencies are installed.

    This does not modify PLM core code. It exists to exercise integrations
    requested by the user (Cirq/volq-quantum) and provide a reproducible
    demonstrator on a toy NP-complete instance.
    """

    try:
        # This module lives alongside this runner; it is imported dynamically
        # so missing optional dependencies don't break the harness.
        from quantum_np_hard_demo import (  # type: ignore
            run_cirq_smoke_demo,
            run_cirq_grover_3sat_demo,
            run_volq_grover_3sat_demo,
        )
    except Exception as exc:
        return [
            CheckResult(
                name="quantum_demo_import",
                ok=True,
                details={"skipped": True, "reason": f"import failed: {exc}"},
            )
        ]

    results: List[CheckResult] = []

    cirq_res = run_cirq_smoke_demo()
    results.append(
        CheckResult(
            name="cirq_smoke",
            ok=bool(cirq_res.ok),
            details={"skipped": cirq_res.skipped, "engine": cirq_res.engine, **cirq_res.details},
        )
    )

    try:
        cirq_shots = int(os.environ.get("CIRQ_SHOTS", "50"))
    except ValueError:
        cirq_shots = 50
    try:
        cirq_iters = int(os.environ.get("CIRQ_ITERS", "0"))
    except ValueError:
        cirq_iters = 0

    cirq_sat_res = run_cirq_grover_3sat_demo(shots=cirq_shots, iters=cirq_iters, seed=0)
    results.append(
        CheckResult(
            name="cirq_grover_3sat_demo",
            ok=bool(cirq_sat_res.ok),
            details={"skipped": cirq_sat_res.skipped, "engine": cirq_sat_res.engine, **cirq_sat_res.details},
        )
    )

    # Keep this demo lightweight; volq backends can be slow in pure Python.
    # You can override for deeper local experimentation.
    try:
        volq_shots = int(os.environ.get("VOLQ_SHOTS", "25"))
    except ValueError:
        volq_shots = 25
    try:
        volq_iters = int(os.environ.get("VOLQ_ITERS", "1"))
    except ValueError:
        volq_iters = 1

    volq_res = run_volq_grover_3sat_demo(shots=volq_shots, iters=volq_iters, seed=0)
    results.append(
        CheckResult(
            name="volq_grover_3sat_demo",
            ok=bool(volq_res.ok),
            details={"skipped": volq_res.skipped, "engine": volq_res.engine, **volq_res.details},
        )
    )

    return results


def main() -> int:
    report_path = Path(__file__).with_name("report.json")
    try:
        checks: List[CheckResult] = []
        checks.append(check_plm_formula())
        checks.extend(check_plm_guardrails())
        checks.append(check_stateful_plm_determinism())
        checks.append(capability_scan_keywords())
        checks.extend(check_quantum_np_hard_demo())

        report: Dict[str, Any] = {
            "repo_root": str(REPO_ROOT),
            "python": sys.version,
            "cwd": os.getcwd(),
            "checks": [asdict(c) for c in checks],
            # "Core" = PLM invariants we can validate deterministically without optional deps.
            "all_core_ok": all(
                c.ok
                for c in checks
                if c.name
                in {
                    "plm_formula_exact_decimal",
                    "mu_nonzero",
                    "c_positive",
                    "hex_valid",
                    "stateful_determinism",
                }
            ),
            # "Optional" = demos/integrations that may be skipped if deps are absent.
            "all_optional_ok": all(
                (c.details.get("skipped") is True) or c.ok
                for c in checks
                if c.name in {"cirq_smoke", "cirq_grover_3sat_demo", "volq_grover_3sat_demo"}
            ),
        }

        try:
            report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        except OSError:
            pass

        print(json.dumps(report, indent=2))

        # Only fail the run if an implemented, core invariant fails.
        if not report["all_core_ok"]:
            return 2
        return 0
    except KeyboardInterrupt:
        crash = {
            "repo_root": str(REPO_ROOT),
            "python": sys.version,
            "cwd": os.getcwd(),
            "error": "KeyboardInterrupt",
        }
        try:
            report_path.write_text(json.dumps(crash, indent=2), encoding="utf-8")
        except OSError:
            pass
        raise
    except Exception as exc:
        crash_path = Path(__file__).with_name("crash_report.json")
        crash = {
            "repo_root": str(REPO_ROOT),
            "python": sys.version,
            "cwd": os.getcwd(),
            "error": str(exc),
            "traceback": traceback.format_exc(),
        }
        try:
            crash_path.write_text(json.dumps(crash, indent=2), encoding="utf-8")
        except OSError:
            pass
        print(json.dumps(crash, indent=2))
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
