# PLM Validation Harness (Non-invasive)

This folder is intentionally **standalone** and **does not modify** PLM.

## What PLM currently implements

In this repository, the core PLM computation is a deterministic transform:

- `plm_formalized.model.plm_secret_value()` computes:

  \[
  S = \frac{(\pi \cdot Y)(\lambda \cdot X)}{(\mu \cdot C)}
  \]

  where:
  - `Y` is derived from `public_hash_hex`
  - `C = block_size + crc_decimal` (must be positive)

Higher-level code wraps this as a discrete-time state machine (`StatefulPLM`) and optionally encodes a time-series into a quantum circuit (`quantum_temporal.py`).

## About NP-hard claims

This harness can **test** PLM against specific benchmark problems, but it cannot *assume* PLM “solves all NP-hard problems” unless there is an implemented solver + a well-defined mapping from those problems into PLM inputs.

So this harness does two things:

1) Verifies **intended implemented behavior** (PLM formula correctness, determinism, guardrails).
2) Performs a **capability scan** for any existing NP-hard solver code in this repo (SAT/TSP/knapsack/etc).

If you want the harness to validate a particular NP-hard problem end-to-end, specify:
- which NP-hard problem (e.g., 3-SAT, TSP, subset-sum)
- what “PLM solving it” means (inputs/outputs, success criteria)
- expected results on a few known instances

## Run

From repo root:

- `python validation_np_hard/run_validation.py`

This will print a JSON report and exit non-zero only if a **core PLM invariant** fails.
