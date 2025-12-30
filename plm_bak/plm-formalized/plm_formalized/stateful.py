# Copyright © 2025 Joshua Harris
# Licensed under the Apache License, Version 2.0

from dataclasses import dataclass, replace
from decimal import Decimal
from typing import Callable

from .model import PLMInputs, plm_secret_value


@dataclass(frozen=True)
class PLMState:
    t: int
    inputs: PLMInputs


UpdateFn = Callable[[PLMState], PLMState]


class StatefulPLM:
    def __init__(self, initial_state: PLMState, update_fn: UpdateFn):
        self._state = initial_state
        self._update_fn = update_fn

    @property
    def state(self) -> PLMState:
        return self._state

    def value(self) -> Decimal:
        return plm_secret_value(self._state.inputs)

    def step(self) -> Decimal:
        self._state = self._update_fn(self._state)
        return self.value()


def update_x_linear(delta: int = 1) -> UpdateFn:
    def fn(st: PLMState) -> PLMState:
        return PLMState(
            t=st.t + 1,
            inputs=replace(st.inputs, x=int(st.inputs.x) + int(delta)),
        )
    return fn
