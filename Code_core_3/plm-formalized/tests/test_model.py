from decimal import Decimal
import pytest

from plm_formalized import (
    PLMInputs,
    hex_to_int,
    plm_ratio,
    plm_secret_value,
)


def test_hex_to_int():
    assert hex_to_int("0x0a") == 10
    assert hex_to_int("ff") == 255


def test_hex_to_int_invalid():
    with pytest.raises(Exception):
        hex_to_int("not-hex")


def test_plm_ratio():
    pi = Decimal("3.14")
    lam = Decimal("2")
    mu = Decimal("4")
    assert plm_ratio(pi, lam, mu) == (pi * lam) / mu


def test_plm_secret_value_deterministic():
    inp = PLMInputs(
        pi=Decimal("3.141592653589793"),
        lam=Decimal("1.618033988749894"),
        mu=Decimal("1"),
        x=123,
        public_hash_hex="a3f1c9",
        block_size=4096,
        crc_decimal=987654321,
    )

    s1 = plm_secret_value(inp)
    s2 = plm_secret_value(inp)
    assert s1 == s2


def test_c_must_be_positive():
    inp = PLMInputs(
        pi=Decimal("3.14"),
        lam=Decimal("1"),
        mu=Decimal("1"),
        x=1,
        public_hash_hex="0a",
        block_size=0,
        crc_decimal=0,
    )

    with pytest.raises(ValueError):
        inp.c()
