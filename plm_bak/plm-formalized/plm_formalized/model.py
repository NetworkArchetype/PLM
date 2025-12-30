# Copyright © 2025 Joshua Harris
# Licensed under the Apache License, Version 2.0

from dataclasses import dataclass
from decimal import Decimal, getcontext
import binascii

getcontext().prec = 80


def hex_to_int(hex_str: str) -> int:
    s = hex_str.strip().lower()
    if s.startswith("0x"):
        s = s[2:]
    binascii.unhexlify(s)  # raises on invalid hex
    return int(s, 16)


@dataclass(frozen=True)
class PLMInputs:
    pi: Decimal
    lam: Decimal
    mu: Decimal
    x: int
    public_hash_hex: str
    block_size: int
    crc_decimal: int

    def y(self) -> int:
        return hex_to_int(self.public_hash_hex)

    def c(self) -> int:
        c_val = int(self.block_size) + int(self.crc_decimal)
        if c_val <= 0:
            raise ValueError("C must be positive")
        return c_val


def plm_ratio(pi: Decimal, lam: Decimal, mu: Decimal) -> Decimal:
    if mu == 0:
        raise ZeroDivisionError("mu cannot be zero")
    return (pi * lam) / mu


def plm_secret_value(inp: PLMInputs) -> Decimal:
    if inp.mu == 0:
        raise ZeroDivisionError("mu cannot be zero")

    numerator = (inp.pi * Decimal(inp.y())) * (inp.lam * Decimal(inp.x))
    denominator = inp.mu * Decimal(inp.c())
    return numerator / denominator
