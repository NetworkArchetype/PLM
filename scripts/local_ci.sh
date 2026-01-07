#!/usr/bin/env bash
set -euo pipefail
WITH_GPU=${WITH_GPU:-0}

step() {
  local name="$1"; shift
  echo "[STEP] $name"
  if "$@"; then
    echo "[OK] $name"
  else
    echo "[FAIL] $name" >&2
    exit 1
  fi
}

step "Create venv" python -m venv venv
step "Upgrade pip" ./venv/Scripts/python.exe -m pip install --upgrade pip setuptools wheel
step "Install PLM (editable)" ./venv/Scripts/python.exe -m pip install -e ./Code_core_3/plm-formalized

if [ "$WITH_GPU" -eq 1 ]; then
  step "Install qsimcirq (GPU)" ./venv/Scripts/python.exe -m pip install qsimcirq
fi

step "Run smoke test" ./venv/Scripts/python.exe test_installation.py

echo "All local CI steps passed."
