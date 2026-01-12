# PLM Install Guide

This guide covers prerequisites and the supported install flows from the CLI and Admin GUI.

## Prerequisites (Windows)
- Windows 11 with hardware virtualization enabled
- Admin rights
- Latest NVIDIA driver with GPU support
- winget (App Installer) available in PATH
- Optional: WSL2 + Ubuntu for Linux-based workflows

## CLI Flow (preferred)
Run from repo root:

1) Install/Start Docker Desktop
```
python scripts/plm_cli.py --install-docker
python scripts/plm_cli.py --ensure-docker
```
2) Install CUDA toolkit (adds nvcc if available in winget channel)
```
python scripts/plm_cli.py --install-cuda-toolkit
```
3) Install TensorFlow (CPU on Windows, GPU on Linux)
```
python scripts/plm_cli.py --install-tensorflow
```
4) Probe GPU/CUDA
```
python scripts/plm_cli.py --probe-cuda
```

## Automated Install Options
Use `start_plm.ps1` for menu-driven install:

- **0**: Auto install + smoke (container preferred, native + container)
- **8**: Auto install native-only (GPU required)
- **9**: Auto install container-only
- **A**: Advanced install (customize options)
- **B**: Auto-detect CUDA: native CUDA/TensorFlow if detected, disabled if not; Container PLM
- **H**: Help/Troubleshooting

Example: `powershell start_plm.ps1` then select B for auto-detect setup.

## Admin GUI Flow
- Launch: `Deploy/PLM-Environment-AdminGUI.fixed.ps1` (elevated).
- Buttons:
  - Start Docker / Install Docker
  - Install CUDA
  - Install TF (CPU on Windows)
  - GPU Fix (runs Docker start + CUDA + TF + probe)
- Use "Probe CUDA/GPU" to verify.
- For automated options, use the CLI menu: `powershell start_plm.ps1`

## Running PLM
After install, run the full PLM simulation:
```
python scripts/plm_cli.py --run-plm
```
This executes the quantum temporal PLM algorithm with Cirq.

## WSL / Docker GPU path
- For TensorFlow GPU on Windows, use Docker GPU sandbox: `python scripts/plm_cli.py --docker-cuda-shell`.
- WSL2 with NVIDIA drivers for full Linux GPU support.

## Logs
- Context log: .plm_session.ndjson
- CLI run: stdout/stderr in terminal
- GUI run: log textbox + context log entry
