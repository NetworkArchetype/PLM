# PLM Quick Start

1) Clone repo and open terminal in repo root.
2) Start Docker Desktop (auto-installs if missing):
```
python scripts/plm_cli.py --install-docker
python scripts/plm_cli.py --ensure-docker
```
3) Try CUDA toolkit (optional):
```
python scripts/plm_cli.py --install-cuda-toolkit
```
4) TensorFlow + Torch (GPU where available; CPU on Windows; see TensorFlow guide):
```
python scripts/plm_cli.py --install-tensorflow
```
5) Verify GPU access:
```
python scripts/plm_cli.py --probe-cuda
```
6) Launch Admin GUI if you prefer buttons:
```
powershell -ExecutionPolicy Bypass -File Deploy/PLM-Environment-AdminGUI.fixed.ps1
```
7) Run smoke test:
```
python scripts/plm_cli.py --smoke
```

Notes:
- If TensorFlow GPU fails on Windows host, use WSL2 or the Docker GPU shell (`--docker-cuda-shell`).
- Logs are appended to .plm_session.ndjson.
