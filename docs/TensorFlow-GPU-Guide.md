# TensorFlow GPU Guide

## Summary
The CLI/GUI provide TensorFlow install on Windows, defaulting to CPU-only since GPU builds are not supported. For GPU, use WSL2 or Docker. The install script automatically handles this by installing `tensorflow` (CPU) on Windows and attempting `tensorflow[and-cuda]` on Linux.

## Recommended paths
- **Windows host (CPU-only)**
  ```
  python scripts/plm_cli.py --install-tensorflow
  ```
  Installs CPU TensorFlow; GPU not supported on Windows.
- **WSL2 / Linux** (recommended for GPU)
  ```
  sudo apt install python3-venv
  python3 -m venv .venv && source .venv/bin/activate
  pip install --upgrade pip
  pip install "tensorflow[and-cuda]==2.16.1"
  ```
- **Docker GPU sandbox**
  ```
  python scripts/plm_cli.py --docker-cuda-shell
  # inside container
  pip install --upgrade pip
  pip install "tensorflow[and-cuda]==2.16.1"
  python - <<'PY'
  import tensorflow as tf
  print(tf.__version__, tf.config.list_physical_devices("GPU"))
  PY
  ```

## Verify on host
```
python scripts/plm_cli.py --probe-cuda
```
- On Windows, TensorFlow will be CPU-only; GPU devices will be empty. Use Docker/WSL for GPU.

## Notes
- Keep NVIDIA drivers current.
- If you only need CPU inference on Windows, install plain `tensorflow` without extras.
- For CUDA toolkit alignment, match toolkit >=12.3 when using TF 2.16.x GPU wheels on Linux.
