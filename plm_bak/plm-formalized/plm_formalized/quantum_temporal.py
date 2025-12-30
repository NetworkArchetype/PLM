# Copyright © 2025 Joshua Harris
# Licensed under the Apache License, Version 2.0

from decimal import Decimal
from math import tau
from typing import List, Dict

import cirq
import sympy

from .stateful import StatefulPLM


def angle_from_S(S: Decimal, scale: float = 1.0) -> float:
    return scale * (float(S) % tau)


def build_circuit():
    q = cirq.LineQubit(0)
    theta = sympy.Symbol("theta")
    circuit = cirq.Circuit(
        cirq.H(q),
        cirq.rz(theta)(q),
        cirq.H(q),
        cirq.measure(q, key="m"),
    )
    return circuit, theta


def simulate_time_series(
    machine: StatefulPLM,
    steps: int,
    scale: float = 1.0,
    shots: int = 2000,
) -> List[Dict]:
    sim = cirq.Simulator()
    circuit, theta = build_circuit()
    out = []

    for _ in range(steps):
        S = machine.value()
        angle = angle_from_S(S, scale)
        result = sim.run(
            circuit,
            param_resolver={"theta": angle},
            repetitions=shots,
        )
        m = result.measurements["m"].mean()
        out.append({
            "t": machine.state.t,
            "S": str(S),
            "theta": float(angle),
            "p1": float(m),
            "expZ": float(1 - 2 * float(m)),
        })
        machine.step()

    return out
