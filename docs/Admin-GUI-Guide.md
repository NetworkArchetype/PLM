# Admin GUI Guide

Scripts: Deploy/PLM-Environment-AdminGUI.ps1 (simple) and Deploy/PLM-Environment-AdminGUI.fixed.ps1 (strict mode with logging).

## Launch
Run elevated PowerShell in repo root:
```
powershell -ExecutionPolicy Bypass -File Deploy/PLM-Environment-AdminGUI.fixed.ps1
```

## Key controls
- Detect: refresh environment detection (winget/git/python/wsl/docker/nvidia/nvcc)
- Install / Repair: winget install core tools
- Update: winget upgrade core tools
- Start Docker / Install Docker: start or winget-install Docker Desktop
- Install CUDA: winget install Nvidia.CUDA
- Install TF GPU: pip install tensorflow[and-cuda] (best-effort; Windows caveat)
- GPU Fix: Start Docker + Install CUDA + Install TF GPU + Probe
- Probe CUDA/GPU: runs nvidia-smi, nvcc, TensorFlow import, Docker GPU probe
- CUDA Shell / Docker CUDA: open host or docker GPU shell

## Logs
- On-screen log box
- Context log: .plm_session.ndjson

## Tips
- Use "Detect" first. If Docker not running, click "Start Docker" or "Install Docker".
- After installing CUDA toolkit, a reboot/logoff may be needed for nvcc PATH.
- TensorFlow GPU on Windows may fail because `nvidia-nccl-cu12` is not published; prefer WSL2/Docker for GPU workloads.
