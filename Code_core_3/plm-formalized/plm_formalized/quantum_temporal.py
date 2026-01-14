from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from math import tau
from typing import List, Tuple, Dict, Any, Optional

from .stateful import StatefulPLM
from .model import plm_secret_value

# Cirq and sympy are optional dependencies.
# Install: pip install cirq sympy
import os
import json

try:
    import cirq  # type: ignore
    import sympy  # type: ignore
except Exception:  # pragma: no cover
    cirq = None  # type: ignore
    sympy = None  # type: ignore


@dataclass(frozen=True)
class QuantumTemporalConfig:
    """
    Quantum temporal model configuration.

    We encode a classical PLM time-series S_t into a parametric quantum circuit:
      theta(t) = scale * (S_t mod 2π)  (or any mapping you choose)

    Then we simulate and measure an observable over time, e.g., <Z> on one qubit.

    This is a "quantum temporal visualization/encoding" of PLM, not a claim
    of quantum advantage or physical correctness.
    """
    scale: float = 1.0
    shots: int = 2000
    use_density_matrix: bool = False


def _decimal_to_float(d: Decimal) -> float:
    # Safe-ish conversion; caller controls precision.
    return float(d)


def angle_from_S(S: Decimal, scale: float = 1.0) -> float:
    """
    Map S (a Decimal) to an angle in radians in [0, 2π) and scale it.
    """
    s = _decimal_to_float(S)
    # modulo 2π into [0, 2π)
    base = s % tau
    return scale * base


def build_parametric_circuit() -> Tuple[cirq.Circuit, sympy.Symbol, cirq.Qid]:
    """
    Build a simple 1-qubit parametric circuit with a symbolic parameter θ:

      |0> --H-- Rz(θ) --H-- measure

    The expectation of Z after this circuit varies with θ.
    """
    if cirq is None or sympy is None:
        raise ImportError("Optional dependency missing: install 'cirq' and 'sympy' to use quantum_temporal")

    q = cirq.LineQubit(0)
    theta = sympy.Symbol("theta")

    circuit = cirq.Circuit(
        cirq.H(q),
        cirq.rz(theta).on(q),
        cirq.H(q),
        cirq.measure(q, key="m"),
    )
    return circuit, theta, q


def simulate_time_series(
    plm_machine: StatefulPLM,
    steps: int,
    cfg: Optional[QuantumTemporalConfig] = None,
) -> List[Dict[str, Any]]:
    """
    Run the stateful PLM machine for `steps`, encode S_t into θ(t),
    simulate the quantum circuit using Cirq, and return a list of records.

    Each record:
      {
        "t": int,
        "S": str (Decimal string),
        "theta": float,
        "p1": float (estimated probability of measuring 1),
        "expZ": float (estimated <Z> = p0 - p1)
      }
    """
    if cfg is None:
        cfg = QuantumTemporalConfig()

    if cirq is None or sympy is None:
        raise ImportError("Optional dependency missing: install 'cirq' and 'sympy' to use simulate_time_series")

    circuit, theta_sym, q = build_parametric_circuit()

    # Check for CUDA config
    config_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'cuda_config.json')
    cuda_enabled = False
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                cuda_enabled = config.get('CUDA_Enabled', False)
        except Exception:
            pass

    if cuda_enabled:
        try:
            import qsimcirq
            # Prefer GPU execution when available, but fall back gracefully if the
            # installed qsim build does not include GPU support.
            try:
                sim = qsimcirq.QSimSimulator(qsim_options=qsimcirq.QSimOptions(use_gpu=True))
            except Exception:
                sim = qsimcirq.QSimSimulator()
        except ImportError:
            try:
                import tensorflow as tf
                sim = cirq.TensorFlowSimulator()
            except ImportError:
                sim = cirq.Simulator()
    else:
        sim = cirq.Simulator()

    out: List[Dict[str, Any]] = []

    for _ in range(steps):
        S = plm_machine.value()
        th = angle_from_S(S, scale=cfg.scale)

        resolver = cirq.ParamResolver({str(theta_sym): th})

        # Run with repetitions for empirical probabilities.
        result = sim.run(circuit, resolver, repetitions=cfg.shots)
        m = result.measurements["m"].reshape(-1)
        p1 = float(m.mean())
        p0 = 1.0 - p1
        expZ = p0 - p1

        out.append(
            {
                "t": plm_machine.state.t,
                "S": str(S),
                "theta": th,
                "p1": p1,
                "expZ": expZ,
            }
        )

        plm_machine.step()

    return out
