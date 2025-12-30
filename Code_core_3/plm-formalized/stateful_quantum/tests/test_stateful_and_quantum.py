from decimal import Decimal

import pytest

from plm_formalized import PLMInputs
from plm_formalized.stateful import PLMState, StatefulPLM, compose_updates, update_x_linear, update_hash_rollover


def test_stateful_steps_change_t_and_x():
    inp = PLMInputs(
        pi=Decimal("3.141592653589793"),
        lam=Decimal("1.618033988749894"),
        mu=Decimal("1"),
        x=1,
        public_hash_hex="0a",
        block_size=10,
        crc_decimal=1,
    )
    st0 = PLMState(t=0, inputs=inp)
    upd = update_x_linear(2)
    m = StatefulPLM(st0, upd)

    s0 = m.value()
    s1 = m.step()

    assert m.state.t == 1
    assert m.state.inputs.x == 3
    assert s0 != s1


@pytest.mark.skip(reason="Requires cirq optional dependency: pip install -e '.[quantum]'")
def test_quantum_temporal_import():
    import plm_formalized.quantum_temporal as qt
    assert hasattr(qt, "simulate_time_series")
