#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="plm-formalized"
mkdir -p "$REPO_DIR"/{plm_formalized,tests,scripts,ruby}

# -------------------------
# LICENSE (Apache-2.0)
# -------------------------
cat > "$REPO_DIR/LICENSE" <<'EOF'
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS
EOF

# -------------------------
# NOTICE
# -------------------------
cat > "$REPO_DIR/NOTICE" <<'EOF'
PLM Formalized
Copyright © 2025 Joshua Harris

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.

You may obtain a copy of the License at:

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

Author: Joshua Harris
EOF

# -------------------------
# README / PROOFS
# -------------------------
cat > "$REPO_DIR/README.md" <<'EOF'
# PLM Formalized

Formalized implementation of the PLM (Pi–Lambda–Mu) symbolic model, including:
- Algebraic proofs
- A stateful dynamical system
- A quantum temporal encoding using Cirq

Author: Joshua Harris

## Mathematical Definition

PLM ratio:
    PLM(λ, μ) := (π · λ) / μ

Generalized form:
    S = ((π · Y)(λ · X)) / (μ · C)
      = (π · λ / μ) · (X · Y / C)

Where:
- X: application-defined scaling parameter
- Y: integer derived from a hex hash
- C: positive integer (block_size + crc)
- μ ≠ 0

## Proofs
See PROOFS.md

## Quantum Temporal Model
The quantum component is an encoding/representation for analysis and visualization,
not a cryptographic or physics claim.

## License
Apache License 2.0 — Copyright © 2025 Joshua Harris
EOF

cat > "$REPO_DIR/PROOFS.md" <<'EOF'
# PLM Algebraic Proofs

Theorem 1 (Factorization):
    S = ((π·Y)(λ·X))/(μ·C) = (π·λ/μ)·(X·Y/C)

Proof:
    By associativity and commutativity of multiplication.
    QED.

Theorem 2 (Bilinearity):
    Scaling X or Y scales S linearly.

Theorem 3 (Ratio Invariance):
    Scaling X and C by the same factor leaves S unchanged.

Theorem 4 (Monotonicity):
    For positive parameters, S increases strictly with X.

Theorem 5 (Sign Determination):
    sign(S) = sign(π·λ·X·Y / μ)

These results establish algebraic stability but make no claims regarding cryptographic security.
EOF

# -------------------------
# pyproject / gitignore
# -------------------------
cat > "$REPO_DIR/pyproject.toml" <<'EOF'
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "plm-formalized"
version = "0.2.0"
description = "Formalized PLM model with stateful and quantum temporal extensions"
readme = "README.md"
requires-python = ">=3.9"
license = {text = "Apache-2.0"}
authors = [{name = "Joshua Harris"}]
dependencies = []

[project.optional-dependencies]
dev = ["pytest>=7.0"]
quantum = ["cirq>=1.0"]

[tool.setuptools]
packages = ["plm_formalized"]
EOF

cat > "$REPO_DIR/.gitignore" <<'EOF'
__pycache__/
*.pyc
.pytest_cache/
.dist/
build/
*.egg-info/
.venv/
EOF

# -------------------------
# Python package files
# -------------------------
cat > "$REPO_DIR/plm_formalized/__init__.py" <<'EOF'
from .model import PLMInputs, plm_ratio, plm_secret_value, hex_to_int
from .stateful import PLMState, StatefulPLM
from .quantum_temporal import simulate_time_series

__all__ = [
    "PLMInputs",
    "plm_ratio",
    "plm_secret_value",
    "hex_to_int",
    "PLMState",
    "StatefulPLM",
    "simulate_time_series",
]
EOF

cat > "$REPO_DIR/plm_formalized/model.py" <<'EOF'
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
EOF

cat > "$REPO_DIR/plm_formalized/stateful.py" <<'EOF'
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
EOF

cat > "$REPO_DIR/plm_formalized/quantum_temporal.py" <<'EOF'
# Copyright © 2025 Joshua Harris
# Licensed under the Apache License, Version 2.0

from decimal import Decimal
from math import tau
from typing import List, Dict

import cirq
import sympy

from .stateful import StatefulPLM


def angle_from_S(S: Decimal, scale: float = 1.0) -> float:
    return scale * (float(S) % tau)


def build_circuit():
    q = cirq.LineQubit(0)
    theta = sympy.Symbol("theta")
    circuit = cirq.Circuit(
        cirq.H(q),
        cirq.rz(theta)(q),
        cirq.H(q),
        cirq.measure(q, key="m"),
    )
    return circuit, theta


def simulate_time_series(
    machine: StatefulPLM,
    steps: int,
    scale: float = 1.0,
    shots: int = 2000,
) -> List[Dict]:
    sim = cirq.Simulator()
    circuit, theta = build_circuit()
    out = []

    for _ in range(steps):
        S = machine.value()
        angle = angle_from_S(S, scale)
        result = sim.run(
            circuit,
            param_resolver={"theta": angle},
            repetitions=shots,
        )
        m = result.measurements["m"].mean()
        out.append({
            "t": machine.state.t,
            "S": str(S),
            "theta": float(angle),
            "p1": float(m),
            "expZ": float(1 - 2 * float(m)),
        })
        machine.step()

    return out
EOF

# -------------------------
# Tests
# -------------------------
cat > "$REPO_DIR/tests/test_model.py" <<'EOF'
from decimal import Decimal
import pytest

from plm_formalized import PLMInputs, hex_to_int, plm_ratio, plm_secret_value


def test_hex_to_int_basic():
    assert hex_to_int("0x0a") == 10
    assert hex_to_int("ff") == 255


def test_hex_to_int_invalid():
    with pytest.raises(Exception):
        hex_to_int("not-hex")


def test_plm_ratio():
    pi = Decimal("3.14159")
    lam = Decimal("2")
    mu = Decimal("4")
    assert plm_ratio(pi, lam, mu) == (pi * lam) / mu


def test_plm_secret_value_deterministic():
    inp = PLMInputs(
        pi=Decimal("3.141592653589793"),
        lam=Decimal("1.618033988749895"),
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
EOF

cat > "$REPO_DIR/tests/test_stateful.py" <<'EOF'
from decimal import Decimal

from plm_formalized import PLMInputs, PLMState, StatefulPLM
from plm_formalized.stateful import update_x_linear


def test_stateful_steps_change_t_and_x():
    inp = PLMInputs(
        pi=Decimal("3.141592653589793"),
        lam=Decimal("1.618033988749895"),
        mu=Decimal("1"),
        x=1,
        public_hash_hex="0a",
        block_size=10,
        crc_decimal=1,
    )
    st0 = PLMState(t=0, inputs=inp)
    m = StatefulPLM(st0, update_x_linear(2))

    s0 = m.value()
    s1 = m.step()

    assert m.state.t == 1
    assert m.state.inputs.x == 3
    assert s0 != s1
EOF

# -------------------------
# Ruby reference (optional)
# -------------------------
cat > "$REPO_DIR/ruby/plm.rb" <<'EOF'
# Copyright © 2025 Joshua Harris
# Licensed under the Apache License, Version 2.0

require "bigdecimal"

module PLM
  module_function

  def hex_to_int(hex_str)
    s = hex_str.strip.downcase
    s = s[2..] if s.start_with?("0x")
    raise ArgumentError, "invalid hex" unless s.match?(/\A[0-9a-f]+\z/)
    s.to_i(16)
  end

  def plm_ratio(pi:, lam:, mu:)
    mu = BigDecimal(mu.to_s)
    raise ZeroDivisionError, "mu cannot be 0" if mu.zero?
    BigDecimal(pi.to_s) * BigDecimal(lam.to_s) / mu
  end

  # S = ((pi * Y) * (lam * X)) / (mu * C)
  def secret_value(pi:, lam:, mu:, x:, public_hash_hex:, block_size:, crc_decimal:)
    pi = BigDecimal(pi.to_s)
    lam = BigDecimal(lam.to_s)
    mu = BigDecimal(mu.to_s)
    raise ZeroDivisionError, "mu cannot be 0" if mu.zero?

    y = hex_to_int(public_hash_hex)
    c = Integer(block_size) + Integer(crc_decimal)
    raise ArgumentError, "C must be positive" if c <= 0

    numerator = (pi * BigDecimal(y.to_s)) * (lam * BigDecimal(x.to_s))
    denominator = mu * BigDecimal(c.to_s)
    numerator / denominator
  end
end
EOF

# -------------------------
# Runner script
# -------------------------
cat > "$REPO_DIR/scripts/run_quantum_temporal.py" <<'EOF'
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
EOF

chmod +x "$REPO_DIR/scripts/run_quantum_temporal.py"

# Helpful local instructions file
cat > "$REPO_DIR/LOCAL_BUILD.txt" <<'EOF'
Local build / test:

cd plm-formalized
python -m venv .venv
source .venv/bin/activate  # (Windows: .venv\Scripts\activate)
pip install -e ".[dev]"
pytest

Quantum:
pip install -e ".[quantum]"
python scripts/run_quantum_temporal.py
EOF

echo "✅ Repo created at ./$REPO_DIR"
echo "Next:"
echo "  cd $REPO_DIR"
echo "  python -m venv .venv && source .venv/bin/activate"
echo "  pip install -e '.[dev]' && pytest"
echo "  pip install -e '.[quantum]' && python scripts/run_quantum_temporal.py"

