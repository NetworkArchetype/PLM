# PLM Formalized — Proofs & Mathematical Properties

This document proves basic algebraic properties of the PLM transform as implemented in this repo.

## Definitions

Let π, λ, μ be real numbers with μ ≠ 0.

Baseline PLM ratio:
  R(π, λ, μ) := (π · λ) / μ

Generalized scenario transform:
  S(π, λ, μ; X, Y, C) := ((π·Y)(λ·X)) / (μ·C)

where:
- X ∈ Z (or R), typically positive integer
- Y ∈ Z, derived from a hex hash interpreted as an integer
- C ∈ Z, positive integer (e.g., block_size + crc_decimal), so C > 0
- μ ≠ 0

Equivalently:
  S = R(π, λ, μ) · (X·Y/C)

---

## Theorem 1 — Factorization

Claim:
  S(π, λ, μ; X, Y, C) = R(π, λ, μ) · (X·Y/C)

Proof:
  Starting from the definition:
    S = ((π·Y)(λ·X)) / (μ·C)
      = (π·λ/μ) · (X·Y/C)
      = R(π, λ, μ) · (X·Y/C)
  QED.

---

## Theorem 2 — Bilinear scaling in (X, Y)

Claim:
  For scalars a, b (real), with X,Y treated as reals:
    S(...; aX, bY, C) = (ab) · S(...; X, Y, C)

Proof:
  S(...; aX, bY, C)
    = ((π·(bY))(λ·(aX))) / (μ·C)
    = (ab)·((π·Y)(λ·X)) / (μ·C)
    = (ab)·S(...; X, Y, C)
  QED.

Corollary:
  If you scale only X by a: S scales by a.
  If you scale only Y by b: S scales by b.

---

## Theorem 3 — Invariance under common scaling of (X,Y,C)

Claim:
  For any nonzero scalar k:
    S(...; kX, Y, kC) = S(...; X, Y, C)
and similarly:
    S(...; X, kY, kC) = S(...; X, Y, C)

Proof:
  S(...; kX, Y, kC)
    = ((π·Y)(λ·kX)) / (μ·kC)
    = k/k · ((π·Y)(λ·X)) / (μ·C)
    = S(...; X, Y, C)
  QED.

Interpretation:
  S depends on the ratio X/C (and Y/C) rather than absolute magnitudes.

---

## Theorem 4 — Sign properties

Assume C > 0.

Claim:
  sign(S) = sign(π·λ·X·Y/μ)

Proof:
  Since C > 0, dividing by C does not change sign.
  So sign(S) = sign(((π·Y)(λ·X))/μ) = sign(π·λ·X·Y/μ).
  QED.

Corollary:
  If π, λ, X, Y, μ are all positive, then S > 0.

---

## Theorem 5 — Monotonicity in X (for positive parameters)

Assume:
  π > 0, λ > 0, Y > 0, μ > 0, C > 0.

Claim:
  S is strictly increasing in X.

Proof:
  Under the assumptions, define constant K := (π·Y·λ)/(μ·C) > 0.
  Then S = K·X.
  Since K > 0, S increases strictly with X.
  QED.

---

## Theorem 6 — Stability / sensitivity bounds (simple Lipschitz bound)

Assume:
  π, λ, μ, C fixed with μ ≠ 0 and C > 0, and X,Y as reals.

Then:
  |S(X1,Y1) - S(X2,Y2)|
    = |(π·λ)/(μ·C)| · |X1·Y1 - X2·Y2|

A sufficient bound:
  |X1·Y1 - X2·Y2|
    ≤ |X1|·|Y1 - Y2| + |Y2|·|X1 - X2|

So:
  |ΔS|
    ≤ |(π·λ)/(μ·C)| · ( |X1|·|ΔY| + |Y2|·|ΔX| )

This is useful to reason about how changes in X or Y propagate to S.

---

## Non-claims

These proofs establish algebraic properties only.
They do NOT establish cryptographic strength, entropy guarantees, or KDF security.