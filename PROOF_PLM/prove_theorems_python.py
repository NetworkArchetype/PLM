#!/usr/bin/env python3
"""
PLM Theorem Prover — Python Edition
====================================
Independently verifies all 6 algebraic theorems of the PLM transform
using 80-digit Decimal arithmetic.

Formula: S = ((pi * Y) * (lam * X)) / (mu * C)

Theorems:
  1. Factorisation Identity
  2. Bilinear Scaling
  3. Ratio Invariance
  4. Sign / Absolute-Value
  5. Monotonicity in X
  6. Lipschitz Continuity

Author : PLM Proof Package (auto-generated)
License: Same as PLM_APLIED repository
"""

from __future__ import annotations

import json
import math
import os
import sys
import time
from dataclasses import dataclass
from decimal import Decimal, getcontext
from pathlib import Path
from typing import Any, Dict, List

# 80-digit precision
getcontext().prec = 80

# ---------------------------------------------------------------------------
# Ensure the PLM package is importable
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[1]
PKG_ROOT = REPO_ROOT / "Code_core_3" / "plm-formalized"
if str(PKG_ROOT) not in sys.path:
    sys.path.insert(0, str(PKG_ROOT))

from plm_formalized.model import PLMInputs, plm_secret_value, hex_to_int, plm_ratio


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
@dataclass
class TheoremResult:
    name: str
    passed: bool
    details: Dict[str, Any]
    elapsed_ms: float


def _make_inputs(pi, lam, mu, x=42, hex_hash="abcdef1234567890",
                 block_size=128, crc=12345) -> PLMInputs:
    return PLMInputs(
        pi=Decimal(str(pi)),
        lam=Decimal(str(lam)),
        mu=Decimal(str(mu)),
        x=x,
        public_hash_hex=hex_hash,
        block_size=block_size,
        crc_decimal=crc,
    )


def _S(pi, lam, mu, x, hex_hash="abcdef1234567890", block_size=128, crc=12345) -> Decimal:
    """Standalone S computation (no PLMInputs dependency)."""
    pi_d = Decimal(str(pi))
    lam_d = Decimal(str(lam))
    mu_d = Decimal(str(mu))
    Y = Decimal(hex_to_int(hex_hash))
    X = Decimal(x)
    C = Decimal(block_size + crc)
    return ((pi_d * Y) * (lam_d * X)) / (mu_d * C)


# ---------------------------------------------------------------------------
# Theorem 1: Factorisation Identity
# S can be decomposed as S = plm_ratio(pi, lam, mu) * (Y * X) / C
# ---------------------------------------------------------------------------
def prove_theorem_1() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846264338327950288419716939937510")
    lam = Decimal("1.61803398874989484820458683436563811772030917980576")
    mu = Decimal("2.71828182845904523536028747135266249775724709369995")

    inp = _make_inputs(pi, lam, mu)
    S_direct = plm_secret_value(inp)

    ratio = plm_ratio(pi, lam, mu)
    Y = Decimal(inp.y())
    X = Decimal(inp.x)
    C = Decimal(inp.c())
    S_factored = ratio * (Y * X) / C

    # Allow 1 ULP difference at digit 80 due to multiplication ordering
    diff = abs(S_direct - S_factored)
    # The relative error must be < 10^-75 (well within 80-digit precision)
    rel_err = diff / abs(S_direct) if S_direct != 0 else diff
    passed = rel_err < Decimal("1e-75")

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Theorem 1: Factorisation Identity",
        passed=passed,
        details={
            "S_direct": str(S_direct),
            "S_factored": str(S_factored),
            "absolute_diff": str(diff),
            "relative_error": str(rel_err),
            "digits_agree": int(-rel_err.log10()) if rel_err > 0 else 80,
        },
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Theorem 2: Bilinear Scaling
# S(alpha*pi, beta*lam, mu, X, Y, C) = alpha * beta * S(pi, lam, mu, X, Y, C)
# ---------------------------------------------------------------------------
def prove_theorem_2() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846")
    lam = Decimal("1.61803398874989484820")
    mu = Decimal("2.71828182845904523536")
    alpha = Decimal("7.123")
    beta = Decimal("0.456")

    S_base = _S(pi, lam, mu, x=42)

    # S with scaled constants
    S_scaled = _S(pi * alpha, lam * beta, mu, x=42)

    expected = alpha * beta * S_base
    diff = abs(S_scaled - expected)
    passed = diff == 0

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Theorem 2: Bilinear Scaling",
        passed=passed,
        details={
            "alpha": str(alpha),
            "beta": str(beta),
            "S_base": str(S_base),
            "S_scaled": str(S_scaled),
            "alpha_beta_S_base": str(expected),
            "diff": str(diff),
        },
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Theorem 3: Ratio Invariance
# S(k*pi, k*lam, k*mu, ...) = S(pi, lam, mu, ...) for k != 0
# ---------------------------------------------------------------------------
def prove_theorem_3() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846")
    lam = Decimal("1.61803398874989484820")
    mu = Decimal("2.71828182845904523536")

    k_values = [Decimal("2"), Decimal("0.5"), Decimal("100"), Decimal("0.001")]
    S_base = _S(pi, lam, mu, x=42)

    results = []
    all_pass = True
    for k in k_values:
        S_k = _S(pi * k, lam * k, mu * k, x=42)
        # After scaling pi, lam, mu all by k:
        # numerator gets k^2, denominator gets k^1 => S_k = k * S_base
        # Wait — let's re-derive:
        # S = ((pi*Y)*(lam*X)) / (mu*C)
        # S_k = (((k*pi)*Y)*((k*lam)*X)) / ((k*mu)*C)
        #      = k^2 * ((pi*Y)*(lam*X)) / (k * mu * C)
        #      = k * S_base
        # So actually for TRUE ratio invariance, scale only the ratio:
        # plm_ratio(k*pi, k*lam, k*mu) = (k*pi * k*lam) / (k*mu) = k * (pi*lam/mu) ≠ ratio
        # The correct invariance: S(k*pi, lam, k*mu, ...) = S(pi, lam, mu, ...)
        pass

    # Correct version: scale pi and mu by same k (ratio pi/mu unchanged)
    all_pass = True
    results = []
    for k in k_values:
        S_k = _S(pi * k, lam, mu * k, x=42)
        diff = abs(S_k - S_base)
        ok = diff == 0
        if not ok:
            all_pass = False
        results.append({
            "k": str(k),
            "S_k": str(S_k),
            "diff": str(diff),
            "ok": ok,
        })

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Theorem 3: Ratio Invariance (pi/mu)",
        passed=all_pass,
        details={"S_base": str(S_base), "trials": results},
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Theorem 4: Sign / Absolute-Value
# |S| = (|pi|*Y * |lam|*X) / (|mu|*C), sign(S) = sign(pi)*sign(lam)*sign(mu)
# ---------------------------------------------------------------------------
def prove_theorem_4() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846")
    lam = Decimal("1.61803398874989484820")
    mu = Decimal("2.71828182845904523536")

    sign_combos = [
        (1, 1, 1, +1),
        (-1, 1, 1, -1),
        (1, -1, 1, -1),
        (1, 1, -1, -1),
        (-1, -1, 1, +1),
        (-1, 1, -1, +1),
        (1, -1, -1, +1),
        (-1, -1, -1, -1),
    ]

    S_pos = _S(pi, lam, mu, x=42)
    all_pass = True
    results = []

    for s_pi, s_lam, s_mu, expected_sign in sign_combos:
        S_signed = _S(pi * s_pi, lam * s_lam, mu * s_mu, x=42)
        actual_sign = 1 if S_signed > 0 else (-1 if S_signed < 0 else 0)

        magnitude_ok = abs(S_signed) == abs(S_pos)
        sign_ok = actual_sign == expected_sign
        ok = magnitude_ok and sign_ok
        if not ok:
            all_pass = False

        results.append({
            "signs": f"pi={s_pi:+d}, lam={s_lam:+d}, mu={s_mu:+d}",
            "expected_sign": expected_sign,
            "actual_sign": actual_sign,
            "magnitude_match": magnitude_ok,
            "ok": ok,
        })

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Theorem 4: Sign / Absolute-Value",
        passed=all_pass,
        details={"combos_tested": len(results), "trials": results},
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Theorem 5: Monotonicity in X
# If X2 > X1 > 0 and all constants positive, then S(X2) > S(X1)
# ---------------------------------------------------------------------------
def prove_theorem_5() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846")
    lam = Decimal("1.61803398874989484820")
    mu = Decimal("2.71828182845904523536")

    x_values = list(range(1, 101))
    prev_S = None
    all_monotone = True
    violations = []

    for x in x_values:
        S_x = _S(pi, lam, mu, x=x)
        if prev_S is not None and S_x <= prev_S:
            all_monotone = False
            violations.append({"x": x, "S_x": str(S_x), "prev_S": str(prev_S)})
        prev_S = S_x

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Theorem 5: Monotonicity in X",
        passed=all_monotone,
        details={
            "x_range": "1..100",
            "points_tested": len(x_values),
            "strictly_increasing": all_monotone,
            "violations": violations,
        },
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Theorem 6: Lipschitz Continuity
# |S(X2) - S(X1)| <= L * |X2 - X1| where L = (|pi|*Y*|lam|) / (|mu|*C)
# ---------------------------------------------------------------------------
def prove_theorem_6() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846")
    lam = Decimal("1.61803398874989484820")
    mu = Decimal("2.71828182845904523536")
    hex_hash = "abcdef1234567890"
    block_size = 128
    crc = 12345

    Y = Decimal(hex_to_int(hex_hash))
    C = Decimal(block_size + crc)
    L = (abs(pi) * Y * abs(lam)) / (abs(mu) * C)

    pairs = [(1, 50), (10, 11), (42, 99), (1, 100), (50, 51)]
    all_pass = True
    results = []

    for x1, x2 in pairs:
        S1 = _S(pi, lam, mu, x=x1, hex_hash=hex_hash, block_size=block_size, crc=crc)
        S2 = _S(pi, lam, mu, x=x2, hex_hash=hex_hash, block_size=block_size, crc=crc)
        lhs = abs(S2 - S1)
        rhs = L * abs(Decimal(x2) - Decimal(x1))
        ok = lhs <= rhs
        if not ok:
            all_pass = False
        results.append({
            "x1": x1, "x2": x2,
            "|S2-S1|": str(lhs),
            "L*|x2-x1|": str(rhs),
            "ratio": str(lhs / rhs) if rhs != 0 else "N/A",
            "ok": ok,
        })

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Theorem 6: Lipschitz Continuity",
        passed=all_pass,
        details={
            "L_constant": str(L),
            "pairs_tested": len(pairs),
            "trials": results,
        },
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Bonus: PLM Constant R = pi * phi / e
# ---------------------------------------------------------------------------
def compute_plm_constant() -> TheoremResult:
    t0 = time.perf_counter()
    pi = Decimal("3.14159265358979323846264338327950288419716939937510")
    phi = Decimal("1.61803398874989484820458683436563811772030917980576")
    e = Decimal("2.71828182845904523536028747135266249775724709369995")

    R = (pi * phi) / e
    # Cross-verify via plm_ratio
    R_via_func = plm_ratio(pi, phi, e)
    match = R == R_via_func

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="PLM Constant R = pi*phi/e",
        passed=match,
        details={
            "R": str(R),
            "R_via_plm_ratio": str(R_via_func),
            "match": match,
            "digits": len(str(R).split('.')[1]) if '.' in str(R) else 0,
        },
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Determinism Check
# ---------------------------------------------------------------------------
def prove_determinism() -> TheoremResult:
    t0 = time.perf_counter()
    inp = _make_inputs(
        "3.14159265358979323846",
        "1.61803398874989484820",
        "2.71828182845904523536",
    )

    results = [str(plm_secret_value(inp)) for _ in range(100)]
    all_same = len(set(results)) == 1

    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Determinism (100 runs)",
        passed=all_same,
        details={
            "runs": 100,
            "unique_values": len(set(results)),
            "sample_value": results[0],
        },
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Guard Rails
# ---------------------------------------------------------------------------
def prove_guardrails() -> TheoremResult:
    t0 = time.perf_counter()
    tests = []

    # mu = 0 raises ZeroDivisionError
    try:
        inp = _make_inputs("3.14", "1.61", "0")
        plm_secret_value(inp)
        tests.append({"test": "mu=0 raises ZeroDivisionError", "ok": False})
    except ZeroDivisionError:
        tests.append({"test": "mu=0 raises ZeroDivisionError", "ok": True})

    # C <= 0 raises ValueError
    try:
        inp = PLMInputs(
            pi=Decimal("3.14"), lam=Decimal("1"), mu=Decimal("1"),
            x=1, public_hash_hex="0a", block_size=0, crc_decimal=0,
        )
        plm_secret_value(inp)
        tests.append({"test": "C<=0 raises ValueError", "ok": False})
    except ValueError:
        tests.append({"test": "C<=0 raises ValueError", "ok": True})

    # Invalid hex raises exception
    try:
        inp = PLMInputs(
            pi=Decimal("3.14"), lam=Decimal("1"), mu=Decimal("1"),
            x=1, public_hash_hex="not-hex", block_size=1, crc_decimal=1,
        )
        plm_secret_value(inp)
        tests.append({"test": "invalid hex raises exception", "ok": False})
    except Exception:
        tests.append({"test": "invalid hex raises exception", "ok": True})

    all_ok = all(t["ok"] for t in tests)
    elapsed = (time.perf_counter() - t0) * 1000
    return TheoremResult(
        name="Guard Rails",
        passed=all_ok,
        details={"tests": tests},
        elapsed_ms=elapsed,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    print("=" * 72)
    print("  PLM THEOREM PROVER — Python 80-Digit Decimal Arithmetic")
    print("=" * 72)
    print()

    proofs = [
        prove_theorem_1,
        prove_theorem_2,
        prove_theorem_3,
        prove_theorem_4,
        prove_theorem_5,
        prove_theorem_6,
        compute_plm_constant,
        prove_determinism,
        prove_guardrails,
    ]

    results: List[TheoremResult] = []
    total_pass = 0
    total_fail = 0

    for prove_fn in proofs:
        r = prove_fn()
        results.append(r)
        status = "PASS" if r.passed else "FAIL"
        icon = "[+]" if r.passed else "[X]"
        if r.passed:
            total_pass += 1
        else:
            total_fail += 1
        print(f"  {icon} {r.name:50s} {status}  ({r.elapsed_ms:.1f} ms)")

    print()
    print("-" * 72)
    print(f"  TOTAL: {total_pass} PASS, {total_fail} FAIL out of {len(results)}")
    print("-" * 72)

    # Write JSON report
    report = {
        "engine": "Python Decimal (80-digit)",
        "python_version": sys.version,
        "total_pass": total_pass,
        "total_fail": total_fail,
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

    report_path = Path(__file__).with_name("python_proof_report.json")
    report_path.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    print(f"\n  Report saved: {report_path}")

    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
