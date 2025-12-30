from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, getcontext
import binascii

getcontext().prec = 80  # high precision


def hex_to_int(hex_str: str) -> int:
    s = hex_str.strip().lower()
    if s.startswith("0x"):
        s = s[2:]
    # validate hex
    binascii.unhexlify(s)  # raises if invalid
    return int(s, 16)


@dataclass(frozen=True)
class PLMInputs:
    # Core parameters (you can keep as Decimal for precision)
    pi: Decimal
    lam: Decimal
    mu: Decimal

    # Scenario parameters
    x: int                 # app-chosen scaling factor / nonce / etc.
    public_hash_hex: str   # Y source
    block_size: int        # part of C
    crc_decimal: int       # part of C (or replace with alt hash-int)

    def y(self) -> int:
        return hex_to_int(self.public_hash_hex)

    def c(self) -> int:
        # As described: C = block_size + crc_decimal
        c_val = int(self.block_size) + int(self.crc_decimal)
        if c_val <= 0:
            raise ValueError("C must be positive (block_size + crc_decimal).")
        return c_val


def plm_ratio(pi: Decimal, lam: Decimal, mu: Decimal) -> Decimal:
    if mu == 0:
        raise ZeroDivisionError("mu cannot be 0.")
    return (pi * lam) / mu


def plm_secret_value(inp: PLMInputs) -> Decimal:
    """
    Computes S = ((pi*Y)*(lam*X)) / (mu*C)
    as a high-precision Decimal.
    """
    Y = Decimal(inp.y())
    X = Decimal(inp.x)
    C = Decimal(inp.c())

    if inp.mu == 0:
        raise ZeroDivisionError("mu cannot be 0.")

    numerator = (inp.pi * Y) * (inp.lam * X)
    denominator = (inp.mu * C)
    return numerator / denominator


# Example usage:
if __name__ == "__main__":
    example = PLMInputs(
        pi=Decimal("3.14159265358979323846264338327950288419716939937510"),
        lam=Decimal("1.61803398874989484820458683436563811772030917980576"),  # e.g., golden ratio as a placeholder lambda
        mu=Decimal("1.0"),
        x=123456789,
        public_hash_hex="a3f1c9",
        block_size=4096,
        crc_decimal=987654321,
    )

    print("PLM ratio:", plm_ratio(example.pi, example.lam, example.mu))
    print("S:", plm_secret_value(example))
