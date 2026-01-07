from plm_formalized.stateful import PLMState, StatefulPLM, PLMInputs
from plm_formalized.quantum_temporal import simulate_time_series, QuantumTemporalConfig
from decimal import Decimal
import math

pi = Decimal(math.pi)
lam = Decimal('1.61803398874989484820458683436563811772030917980576286213544862270526046281890244970720720418939113748475')
mu = Decimal('2.718281828459045235360287471352662497757247093699959574966967627724076630353547594571382178525166427427')

x = 42
public_hash_hex = 'abcdef1234567890'
block_size = 128
crc_decimal = 12345

inputs = PLMInputs(pi=pi, lam=lam, mu=mu, x=x, public_hash_hex=public_hash_hex, block_size=block_size, crc_decimal=crc_decimal)

def update(state):
    new_x = state.inputs.x + 1
    new_inputs = PLMInputs(pi=state.inputs.pi, lam=state.inputs.lam, mu=state.inputs.mu, x=new_x, public_hash_hex=state.inputs.public_hash_hex, block_size=state.inputs.block_size, crc_decimal=state.inputs.crc_decimal)
    return PLMState(t=state.t + 1, inputs=new_inputs)

initial_state = PLMState(t=0, inputs=inputs)
machine = StatefulPLM(initial_state, update)

cfg = QuantumTemporalConfig(shots=100, scale=1.0)
results = simulate_time_series(machine, steps=5, cfg=cfg)

for r in results:
    print(f't={r["t"]}, S={r["S"][:20]}..., theta={r["theta"]:.3f}, p1={r["p1"]:.3f}, expZ={r["expZ"]:.3f}')