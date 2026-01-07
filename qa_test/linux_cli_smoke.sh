#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

echo "[QA] Repo root: $REPO_ROOT"
python -m compileall scripts/plm_cli.py

# Best-effort CUDA probe; do not fail pipeline if missing GPU
if ! python scripts/plm_cli.py --log-level debug --env; then
  echo "[QA] env check failed" >&2
  exit 1
fi
echo "[QA] TensorFlow GPU check" && python - <<'EOF'
import sys, json
PROBE_CUDA=${PROBE_CUDA:-1}
INSTALL_TF=${INSTALL_TF:-1}
  import tensorflow as tf
  info = {"version": tf.__version__, "gpus": [d.name for d in tf.config.list_physical_devices("GPU")]} 
  print(json.dumps(info))
  sys.exit(0)
except Exception as e:
  print(f"TF_NOT_READY {e}")
  sys.exit(1)
EOF
python scripts/plm_cli.py --log-level debug --probe-cuda --export-report || echo "[QA] probe-cuda best-effort failure tolerated"

echo "[QA] Done"
