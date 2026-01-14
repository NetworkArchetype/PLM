#!/usr/bin/env python3
"""Validate a fresh local install (imports + basic runs + diagnostics)."""

import sys
from decimal import Decimal


def test_imports() -> None:
    """Ensure key dependencies are importable (warn on optional GPU libs)."""
    import pytest

    cirq = pytest.importorskip("cirq")
    import plm_formalized

    print(f"- Cirq installed: {cirq.__version__}")
    print("- PLM formalized package imported")

    try:
        import qsimcirq  # optional GPU accel

        print("- QSimCirq detected (GPU-capable simulator)")
    except ImportError as e:
        print(f"- QSimCirq not found (ok, CPU simulator will be used): {e}")


def test_basic_functionality() -> None:
    """Run a small Cirq circuit and compute simple stats."""
    import pytest

    cirq = pytest.importorskip("cirq")

    qubits = cirq.LineQubit.range(2)
    circuit = cirq.Circuit(
        cirq.H(qubits[0]),
        cirq.CNOT(qubits[0], qubits[1]),
        cirq.measure(*qubits, key="m"),
    )
    print("- Basic Cirq circuit created")

    simulator = cirq.Simulator()
    result = simulator.run(circuit, repetitions=200)
    raw = result.measurements["m"]
    assert raw.shape == (200, 2), f"Expected (200, 2) measurement matrix, got {raw.shape}"

    m = raw.reshape(-1)
    p1 = float(m.mean())
    p0 = 1.0 - p1

    assert len(m) == 400, "Expected 400 measurements (200 shots * 2 qubits)"
    assert 0.0 <= p1 <= 1.0, "Probability p1 must be within [0, 1]"

    print(
        f"- Circuit simulation completed: {m.size} shots, p1={p1:.3f}, p0={p0:.3f}, expZ={p0 - p1:.3f}"
    )


def test_plm_components() -> None:
    """Exercise core PLM math + stateful + quantum temporal path."""
    import pytest

    pytest.importorskip("cirq")
    pytest.importorskip("sympy")

    from plm_formalized.model import PLMInputs, plm_secret_value
    from plm_formalized.stateful import PLMState, StatefulPLM, update_x_linear
    from plm_formalized.quantum_temporal import QuantumTemporalConfig, simulate_time_series

    base_inputs = PLMInputs(
        pi=Decimal("3.14159265358979323846"),
        lam=Decimal("1.61803398874989484820"),
        mu=Decimal("1.0"),
        x=42,
        public_hash_hex="a3f1c9",
        block_size=4096,
        crc_decimal=987654,
    )

    s0 = plm_secret_value(base_inputs)
    print(f"- PLM secret value (S0) computed: {s0}")

    init_state = PLMState(t=0, inputs=base_inputs)
    machine = StatefulPLM(init_state, update_x_linear(delta=1))

    cfg = QuantumTemporalConfig(scale=1.0, shots=128)
    records = simulate_time_series(machine, steps=3, cfg=cfg)

    assert len(records) == 3, "Expected three time steps"

    for rec in records:
        assert "p1" in rec and "expZ" in rec, "Record missing probability fields"
        print(f"- t={rec['t']}, theta={rec['theta']:.4f}, p1={rec['p1']:.3f}, expZ={rec['expZ']:.3f}")


if __name__ == "__main__":
    print("=== PLM Installation Test ===")
    print()

    success = True
    for fn in (test_imports, test_basic_functionality, test_plm_components):
        try:
            fn()
        except Exception as e:
            success = False
            print(f"- {fn.__name__} failed: {e}")
        finally:
            print()

    if success:
        print("- All tests passed! PLM is ready to use.")
        sys.exit(0)
    else:
        print("- Some tests failed. Check the output above for details.")
        sys.exit(1)