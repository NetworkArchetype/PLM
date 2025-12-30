#!/usr/bin/env python3
from decimal import Decimal

from plm_formalized import PLMInputs, PLMState, StatefulPLM, simulate_time_series
from plm_formalized.stateful import update_x_linear

inputs = PLMInputs(
    pi=Decimal("3.141592653589793"),
    lam=Decimal("1.618033988749895"),
    mu=Decimal("1.0"),
    x=1,
    public_hash_hex="0001",
    block_size=4096,
    crc_decimal=100,
)

state0 = PLMState(t=0, inputs=inputs)
machine = StatefulPLM(state0, update_x_linear(delta=1))

data = simulate_time_series(machine, steps=10, scale=1.0, shots=2000)

print("t,S,theta,p1,expZ")
for row in data:
    print(f"{row['t']},{row['S']},{row['theta']},{row['p1']},{row['expZ']}")
