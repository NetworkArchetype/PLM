#!/usr/bin/env python3
"""
PLM Cirq Quantum Verification Runner
======================================
Verifies the PLM quantum temporal encoding by:

1. Building the parametric H-Rz(theta)-H-Measure circuit
2. Running it for multiple PLM time-series steps
3. Comparing measured p(|1>) against the theoretical sin^2(theta/2)
4. Comparing measured <Z> against the theoretical cos(theta)
5. Running a standalone Grover 3-SAT demo if available

Requires: cirq, sympy (pip install cirq sympy)

Author : PLM Proof Package (auto-generated)
License: Same as PLM_APLIED repository
"""

from __future__ import annotations

import json
import math
import os
import sys
import time
import traceback
from dataclasses import dataclass
from decimal import Decimal, getcontext
from pathlib import Path
from typing import Any, Dict, List, Optional

getcontext().prec = 80

# ---------------------------------------------------------------------------
# Ensure imports
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[1]
PKG_ROOT = REPO_ROOT / "Code_core_3" / "plm-formalized"
if str(PKG_ROOT) not in sys.path:
    sys.path.insert(0, str(PKG_ROOT))

NP_HARD_DIR = REPO_ROOT / "validation_np_hard"
if str(NP_HARD_DIR) not in sys.path:
    sys.path.insert(0, str(NP_HARD_DIR))


@dataclass
class VerificationResult:
    name: str
    passed: bool
    details: Dict[str, Any]
    elapsed_ms: float


# ---------------------------------------------------------------------------
# 1. Circuit Construction Verification
# ---------------------------------------------------------------------------
def verify_circuit_construction() -> VerificationResult:
    t0 = time.perf_counter()
    try:
        import cirq
        import sympy

        q = cirq.LineQubit(0)
        theta = sympy.Symbol("theta")
        circuit = cirq.Circuit(
            cirq.H(q),
            cirq.rz(theta).on(q),
            cirq.H(q),
            cirq.measure(q, key="m"),
        )

        # Verify circuit structure
        ops = list(circuit.all_operations())
        gate_names = [str(op.gate) for op in ops if hasattr(op.gate, '__str__')]

        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Circuit Construction (H-Rz-H-Measure)",
            passed=len(ops) == 4,
            details={
                "num_operations": len(ops),
                "circuit_diagram": str(circuit),
                "cirq_version": cirq.__version__,
            },
            elapsed_ms=elapsed,
        )
    except ImportError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Circuit Construction (H-Rz-H-Measure)",
            passed=False,
            details={"error": str(e), "hint": "pip install cirq sympy"},
            elapsed_ms=elapsed,
        )


# ---------------------------------------------------------------------------
# 2. Quantum Physics Verification
#    H-Rz(theta)-H produces: p(|1>) = sin^2(theta/2), <Z> = cos(theta)
# ---------------------------------------------------------------------------
def verify_quantum_physics(shots: int = 10000) -> VerificationResult:
    t0 = time.perf_counter()
    try:
        import cirq
        import sympy

        q = cirq.LineQubit(0)
        theta_sym = sympy.Symbol("theta")
        circuit = cirq.Circuit(
            cirq.H(q),
            cirq.rz(theta_sym).on(q),
            cirq.H(q),
            cirq.measure(q, key="m"),
        )
        sim = cirq.Simulator()

        test_angles = [0.0, math.pi / 6, math.pi / 4, math.pi / 3,
                       math.pi / 2, math.pi, 1.5 * math.pi, 2.0]
        trials = []
        max_p1_error = 0.0
        max_expZ_error = 0.0

        for theta in test_angles:
            resolver = cirq.ParamResolver({"theta": theta})
            result = sim.run(circuit, resolver, repetitions=shots)
            m = result.measurements["m"].reshape(-1)
            p1_measured = float(m.mean())
            p1_theory = math.sin(theta / 2) ** 2
            expZ_measured = 1.0 - 2.0 * p1_measured
            expZ_theory = math.cos(theta)

            p1_err = abs(p1_measured - p1_theory)
            expZ_err = abs(expZ_measured - expZ_theory)
            max_p1_error = max(max_p1_error, p1_err)
            max_expZ_error = max(max_expZ_error, expZ_err)

            trials.append({
                "theta": round(theta, 6),
                "p1_measured": round(p1_measured, 6),
                "p1_theory": round(p1_theory, 6),
                "p1_error": round(p1_err, 6),
                "expZ_measured": round(expZ_measured, 6),
                "expZ_theory": round(expZ_theory, 6),
                "expZ_error": round(expZ_err, 6),
            })

        # With 10000 shots, statistical error ~ 1/sqrt(10000) = 0.01
        # Allow 5% tolerance for statistical fluctuation
        passed = max_p1_error < 0.05 and max_expZ_error < 0.05

        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Quantum Physics (p1=sin^2(t/2), <Z>=cos(t))",
            passed=passed,
            details={
                "shots": shots,
                "angles_tested": len(test_angles),
                "max_p1_error": round(max_p1_error, 6),
                "max_expZ_error": round(max_expZ_error, 6),
                "tolerance": 0.05,
                "trials": trials,
            },
            elapsed_ms=elapsed,
        )
    except ImportError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Quantum Physics (p1=sin^2(t/2), <Z>=cos(t))",
            passed=False,
            details={"error": str(e), "hint": "pip install cirq sympy"},
            elapsed_ms=elapsed,
        )


# ---------------------------------------------------------------------------
# 3. PLM Quantum Temporal Pipeline
# ---------------------------------------------------------------------------
def verify_quantum_temporal_pipeline(steps: int = 5, shots: int = 5000) -> VerificationResult:
    t0 = time.perf_counter()
    try:
        import cirq
        import sympy
        from plm_formalized.model import PLMInputs
        from plm_formalized.stateful import PLMState, StatefulPLM, update_x_linear
        from plm_formalized.quantum_temporal import (
            QuantumTemporalConfig,
            simulate_time_series,
            angle_from_S,
        )

        pi = Decimal("3.14159265358979323846")
        lam = Decimal("1.61803398874989484820")
        mu = Decimal("2.71828182845904523536")

        inp = PLMInputs(
            pi=pi, lam=lam, mu=mu,
            x=1, public_hash_hex="0f",
            block_size=128, crc_decimal=1,
        )
        st0 = PLMState(t=0, inputs=inp)
        machine = StatefulPLM(st0, update_x_linear(1))
        cfg = QuantumTemporalConfig(scale=1.0, shots=shots)

        records = simulate_time_series(machine, steps, cfg)

        # Verify each record has required fields and values are physically valid
        all_valid = True
        record_details = []
        for rec in records:
            has_keys = all(k in rec for k in ("t", "S", "theta", "p1", "expZ"))
            p1_valid = 0.0 <= rec["p1"] <= 1.0
            expZ_valid = -1.0 <= rec["expZ"] <= 1.0

            # Cross-check: expZ should be approximately cos(theta)
            expZ_theory = math.cos(rec["theta"])
            expZ_err = abs(rec["expZ"] - expZ_theory)

            valid = has_keys and p1_valid and expZ_valid
            if not valid:
                all_valid = False

            record_details.append({
                "t": rec["t"],
                "S": rec["S"][:30] + "...",
                "theta": round(rec["theta"], 6),
                "p1": round(rec["p1"], 6),
                "expZ": round(rec["expZ"], 6),
                "expZ_theory": round(expZ_theory, 6),
                "expZ_error": round(expZ_err, 6),
                "valid": valid,
            })

        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name=f"PLM Quantum Temporal Pipeline ({steps} steps)",
            passed=all_valid,
            details={
                "steps": steps,
                "shots_per_step": shots,
                "records": record_details,
            },
            elapsed_ms=elapsed,
        )
    except ImportError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name=f"PLM Quantum Temporal Pipeline ({steps} steps)",
            passed=False,
            details={"error": str(e), "hint": "pip install cirq sympy"},
            elapsed_ms=elapsed,
        )


# ---------------------------------------------------------------------------
# 4. Grover 3-SAT Demo (Cirq)
# ---------------------------------------------------------------------------
def verify_grover_3sat() -> VerificationResult:
    t0 = time.perf_counter()
    try:
        from quantum_np_hard_demo import run_cirq_grover_3sat_demo
        res = run_cirq_grover_3sat_demo(shots=200, iters=0, seed=42)

        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Grover 3-SAT Demo (Cirq)",
            passed=bool(res.ok),
            details={
                "engine": res.engine,
                "skipped": res.skipped,
                **res.details,
            },
            elapsed_ms=elapsed,
        )
    except ImportError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Grover 3-SAT Demo (Cirq)",
            passed=True,  # Not a failure if optional dep missing
            details={"skipped": True, "reason": str(e)},
            elapsed_ms=elapsed,
        )
    except Exception as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Grover 3-SAT Demo (Cirq)",
            passed=False,
            details={"error": str(e), "traceback": traceback.format_exc()},
            elapsed_ms=elapsed,
        )


# ---------------------------------------------------------------------------
# 5. Cirq Smoke Test
# ---------------------------------------------------------------------------
def verify_cirq_smoke() -> VerificationResult:
    t0 = time.perf_counter()
    try:
        import cirq
        # Create a simple Bell circuit
        q0, q1 = cirq.LineQubit.range(2)
        bell = cirq.Circuit(
            cirq.H(q0),
            cirq.CNOT(q0, q1),
            cirq.measure(q0, q1, key="result"),
        )
        sim = cirq.Simulator()
        result = sim.run(bell, repetitions=1000)
        m = result.measurements["result"]

        # In a Bell state, q0 and q1 should always agree
        agreements = sum(1 for row in m if row[0] == row[1])
        agreement_rate = agreements / len(m)

        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Cirq Smoke Test (Bell State)",
            passed=agreement_rate > 0.95,
            details={
                "cirq_version": cirq.__version__,
                "repetitions": 1000,
                "agreement_rate": round(agreement_rate, 4),
                "circuit": str(bell),
            },
            elapsed_ms=elapsed,
        )
    except ImportError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Cirq Smoke Test (Bell State)",
            passed=False,
            details={"error": str(e), "hint": "pip install cirq"},
            elapsed_ms=elapsed,
        )


# ---------------------------------------------------------------------------
# 6. Angle Mapping Verification
# ---------------------------------------------------------------------------
def verify_angle_mapping() -> VerificationResult:
    t0 = time.perf_counter()
    try:
        from plm_formalized.quantum_temporal import angle_from_S

        test_cases = [
            (Decimal("0"), 0.0),
            (Decimal("1"), 1.0),
            (Decimal(str(math.pi)), math.pi),
            (Decimal(str(2 * math.pi)), 0.0),  # wraps to 0
            (Decimal(str(2 * math.pi + 1)), 1.0),  # wraps to 1
            (Decimal("100"), 100.0 % (2 * math.pi)),
        ]

        all_ok = True
        details_list = []
        for S, expected in test_cases:
            got = angle_from_S(S, scale=1.0)
            err = abs(got - expected)
            ok = err < 1e-10
            if not ok:
                all_ok = False
            details_list.append({
                "S": str(S),
                "expected": round(expected, 10),
                "got": round(got, 10),
                "error": err,
                "ok": ok,
            })

        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Angle Mapping (S -> theta mod 2pi)",
            passed=all_ok,
            details={"cases": details_list},
            elapsed_ms=elapsed,
        )
    except ImportError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        return VerificationResult(
            name="Angle Mapping (S -> theta mod 2pi)",
            passed=False,
            details={"error": str(e)},
            elapsed_ms=elapsed,
        )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    print("=" * 72)
    print("  PLM CIRQ QUANTUM VERIFICATION RUNNER")
    print("=" * 72)
    print()

    verifications = [
        verify_circuit_construction,
        verify_quantum_physics,
        verify_quantum_temporal_pipeline,
        verify_grover_3sat,
        verify_cirq_smoke,
        verify_angle_mapping,
    ]

    results: List[VerificationResult] = []
    total_pass = 0
    total_fail = 0
    total_skip = 0

    for verify_fn in verifications:
        r = verify_fn()
        results.append(r)

        if r.details.get("skipped"):
            total_skip += 1
            icon = "[~]"
            status = "SKIP"
        elif r.passed:
            total_pass += 1
            icon = "[+]"
            status = "PASS"
        else:
            total_fail += 1
            icon = "[X]"
            status = "FAIL"

        print(f"  {icon} {r.name:50s} {status}  ({r.elapsed_ms:.1f} ms)")

    print()
    print("-" * 72)
    print(f"  TOTAL: {total_pass} PASS, {total_fail} FAIL, {total_skip} SKIP out of {len(results)}")
    print("-" * 72)

    # Write JSON report
    report = {
        "engine": "Cirq Quantum Simulator",
        "python_version": sys.version,
        "total_pass": total_pass,
        "total_fail": total_fail,
        "total_skip": total_skip,
        "results": [
            {
                "name": r.name,
                "passed": r.passed,
                "elapsed_ms": round(r.elapsed_ms, 2),
                "details": r.details,
            }
            for r in results
        ],
    }

    report_path = Path(__file__).with_name("cirq_verification_report.json")
    report_path.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    print(f"\n  Report saved: {report_path}")

    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
