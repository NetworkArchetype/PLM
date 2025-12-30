# PLM Formalized

This repository repackages and formalizes the **PLM (Pi–Lambda–Mu)** symbolic model into a small, testable library.

## Symbolic definition

Baseline PLM ratio:
  PLM(λ, μ) := (π · λ) / μ

Generalized scenario:
  S = ((π · Y)(λ · X)) / (μ · C)
  S = (π · λ / μ) · (X · Y / C)

Where:
- Y : integer derived from a hex hash string
- X : application-chosen scaling factor / nonce / session-derived integer
- C : positive integer derived from (block_size + crc_decimal)
- S : numeric output of the transform

## Proofs
See: PROOFS.md

## Python package

Install locally:
  pip install -e .

### Basic usage

from decimal import Decimal
from plm_formalized import PLMInputs, plm_ratio, plm_secret_value

inp = PLMInputs(
    pi=Decimal("3.14159265358979323846264338327950288419716939937510"),
    lam=Decimal("1.61803398874989484820458683436563811772030917980576"),
    mu=Decimal("1.0"),
    x=123456789,
    public_hash_hex="a3f1c9",
    block_size=4096,
    crc_decimal=987654321,
)

print(plm_ratio(inp.pi, inp.lam, inp.mu))
print(plm_secret_value(inp))

## Stateful model

from plm_formalized import PLMState, StatefulPLM
from plm_formalized.stateful import compose_updates, update_x_linear, update_hash_rollover

st0 = PLMState(t=0, inputs=inp)
upd = compose_updates(update_x_linear(1), update_hash_rollover(16))
machine = StatefulPLM(st0, upd)

for _ in range(5):
    s = machine.value()
    print(machine.state.t, s)
    machine.step()

## Quantum temporal model (Cirq)

Install:
  pip install -e ".[quantum]"

from plm_formalized import QuantumTemporalConfig, simulate_time_series

cfg = QuantumTemporalConfig(scale=1.0, shots=2000)
series = simulate_time_series(machine, steps=10, cfg=cfg)

for row in series:
    print(row)

Note:
This is a "quantum encoding / visualization" of the PLM time-series. It is not a cryptographic or physics claim.

## Tests
  pytest

## License
Apache 2.0 License
See LICENSE file.
