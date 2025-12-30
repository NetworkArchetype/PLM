from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, getcontext
import binascii

# High precision by default
getcontext().prec = 80


def hex_to_int(hex_str: str) -> int:
    """
    Convert a hex string (optional 0x prefix) into an integer.
    """
    s = hex_str.strip().lower()
    if s.startswith("0x"):
        s = s[2:]
    binascii.unhexlify(s)  # raises on invalid hex
    return int(s, 16)


@dataclass(frozen=True)
class PLMInputs:
    """
    Inputs for the generalized PLM computation.

    S = ((pi * Y) * (lam * X)) / (mu * C)
    """
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
    """
    Compute (pi * lam) / mu
    """
    if mu == 0:
        raise ZeroDivisionError("mu cannot be 0")
    return (pi * lam) / mu


def plm_secret_value(inp: PLMInputs) -> Decimal:
    """
    Compute S = ((pi * Y) * (lam * X)) / (mu * C)
    """
    if inp.mu == 0:
        raise ZeroDivisionError("mu cannot be 0")

    Y = Decimal(inp.y())
    X = Decimal(inp.x)
    C = Decimal(inp.c())

    numerator = (inp.pi * Y) * (inp.lam * X)
    denominator = inp.mu * C
    return numerator / denominator
