# CUDA Guide

## Goals
- Install CUDA toolkit (nvcc) on Windows via winget
- Probe GPU access from host and Docker

## Install
```
python scripts/plm_cli.py --install-cuda-toolkit
```
If winget reports "already installed" but nvcc is missing, sign out/in or reboot to refresh PATH.

## Verify
```
python scripts/plm_cli.py --probe-cuda
```
Expected:
- nvidia-smi OK
- nvcc OK (if toolkit installed and PATH refreshed)
- Docker GPU probe OK (requires Docker Desktop + NVIDIA runtime)

## GUI path
Use Admin GUI buttons: Install CUDA, Probe CUDA/GPU, or GPU Fix for a one-click sequence.

## Troubleshooting
- nvcc missing: reopen shell after logoff/reboot; check `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA` in PATH.
- Driver mismatch: update NVIDIA driver via GeForce/Studio drivers before retrying.
- Docker GPU failure: ensure Docker Desktop has WSL2 backend and "Use GPU support" enabled; run `python scripts/plm_cli.py --ensure-docker` first.
