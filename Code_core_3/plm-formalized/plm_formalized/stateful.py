from __future__ import annotations

from dataclasses import dataclass, replace
from decimal import Decimal
from typing import Callable, Optional, Dict, Any

from .model import PLMInputs, plm_secret_value


@dataclass(frozen=True)
class PLMState:
    """
    Discrete-time / stateful PLM model.

    At each step t -> t+1, we update some subset of the inputs (X, hash, C components)
    and compute S_t.

    This is *not* a security model; it's a deterministic state machine around the PLM transform.
    """
    t: int
    inputs: PLMInputs


UpdateFn = Callable[[PLMState], PLMState]


class StatefulPLM:
    """
    A clean state machine wrapper for iterating PLM over time.

    - You provide an initial state.
    - You provide an update function that returns the next state.
    - The machine computes S at each step deterministically.
    """
    def __init__(
        self,
        initial_state: PLMState,
        update_fn: UpdateFn,
        observer: Optional[Callable[[PLMState, Decimal], None]] = None,
    ) -> None:
        self._state = initial_state
        self._update_fn = update_fn
        self._observer = observer

    @property
    def state(self) -> PLMState:
        return self._state

    def value(self) -> Decimal:
        """Compute S for the current state."""
        return plm_secret_value(self._state.inputs)

    def step(self) -> Decimal:
        """
        Advance one timestep, compute and return the new S.
        Order:
          1) state <- update_fn(state)
          2) compute S
          3) observer(state, S) if provided
        """
        self._state = self._update_fn(self._state)
        s = self.value()
        if self._observer is not None:
            self._observer(self._state, s)
        return s


# ----------------------------
# Example update strategies
# ----------------------------

def update_x_linear(delta: int = 1) -> UpdateFn:
    """Increase X by a fixed delta each step."""
    def _fn(st: PLMState) -> PLMState:
        inp = st.inputs
        new_inp = replace(inp, x=int(inp.x) + int(delta))
        return PLMState(t=st.t + 1, inputs=new_inp)
    return _fn


def update_c_add_crc(delta_crc: int = 1) -> UpdateFn:
    """Increase crc_decimal by delta each step (thus increasing C)."""
    def _fn(st: PLMState) -> PLMState:
        inp = st.inputs
        new_inp = replace(inp, crc_decimal=int(inp.crc_decimal) + int(delta_crc))
        return PLMState(t=st.t + 1, inputs=new_inp)
    return _fn


def update_hash_rollover(n_bits: int = 16) -> UpdateFn:
    """
    Deterministically mutate the public_hash_hex by interpreting it as an int,
    adding 1, and wrapping mod 2^n_bits. Produces a fixed-width hex string.
    """
    width = max(1, (n_bits + 3) // 4)
    modulus = 1 << n_bits

    def _fn(st: PLMState) -> PLMState:
        inp = st.inputs
        y = int(inp.y())
        y2 = (y + 1) % modulus
        hex2 = format(y2, "0{}x".format(width))
        new_inp = replace(inp, public_hash_hex=hex2)
        return PLMState(t=st.t + 1, inputs=new_inp)

    return _fn


def compose_updates(*updates: UpdateFn) -> UpdateFn:
    """Compose multiple update fns into one."""
    def _fn(st: PLMState) -> PLMState:
        cur = st
        for u in updates:
            cur = u(cur)
        return cur
    return _fn
