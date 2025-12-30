#!/usr/bin/env python3
"""
Run a stateful PLM model and encode its temporal evolution into a
quantum circuit using Cirq.

Outputs a CSV-like table:
t,S,theta,p1,expZ

Requirements:
  pip install -e .
  pip install -e ".[quantum]"
"""

from decimal import Decimal

from plm_formalized import (
    PLMInputs,
    PLMState,
    StatefulPLM,
    QuantumTemporalConfig,
    simulate_time_series,
)

from plm_formalized.stateful import (
    compose_updates,
    update_x_linear,
    update_hash_rollover,
)


def main():
    # ----------------------------
    # Initial PLM inputs
    # ----------------------------
    inputs = PLMInputs(
        pi=Decimal("3.14159265358979323846264338327950288419716939937510"),
        lam=Decimal("1.61803398874989484820458683436563811772030917980576"),
        mu=Decimal("1.0"),
        x=1,
        public_hash_hex="0001",
        block_size=4096,
        crc_decimal=100,
    )

    # Initial state
    state0 = PLMState(t=0, inputs=inputs)

    # ----------------------------
    # Stateful update rule
    # ----------------------------
    # - Increment X each step
    # - Roll the hash deterministically (16-bit space)
    update_fn = compose_updates(
        update_x_linear(delta=1),
        update_hash_rollover(n_bits=16),
    )

    machine = StatefulPLM(state0, update_fn)

    # ----------------------------
    # Quantum temporal configuration
    # ----------------------------
    cfg = QuantumTemporalConfig(
        scale=1.0,     # scales theta = scale * (S mod 2π)
        shots=2000,    # measurement repetitions
    )

    # ----------------------------
    # Run simulation
    # ----------------------------
    steps = 20
    records = simulate_time_series(machine, steps=steps, cfg=cfg)

    # ----------------------------
    # Output CSV
    # ----------------------------
    print("t,S,theta,p1,expZ")
    for r in records:
        print(
            f"{r['t']},"
            f"{r['S']},"
            f"{r['theta']:.8f},"
            f"{r['p1']:.6f},"
            f"{r['expZ']:.6f}"
        )


if __name__ == "__main__":
    main()
