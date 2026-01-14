# PLM Quick Start Guide

## Get Started in 5 Minutes

### 1. Fast start (GUI or CLI)
```powershell
powershell -ExecutionPolicy Bypass -File .\start_plm.ps1
```
Pick **Admin GUI** (full operator console), **CLI console** (same actions from terminal), or automated install options (0-9,A,B,H).

### 2. Manual setup (if you prefer)
```bash
git clone https://github.com/NetworkArchetype/PLM.git
cd PLM
python -m venv venv
\.\venv\Scripts\activate
pip install -e .
pip install -e ".[quantum]"
```

Run the smoke test (verifies Cirq + PLM + basic functionality):

```bash
.\venv\Scripts\python.exe .\scripts\plm_cli.py --smoke
```

Install the recommended ML stack (TensorFlow + Torch; GPU where available, CPU on Windows):

```bash
.\venv\Scripts\python.exe .\scripts\plm_cli.py --install-tf-gpu
```

Or run the full PLM quantum temporal simulation:

```bash
.\venv\Scripts\python.exe .\scripts\plm_cli.py --run-plm
```

### 3. Enable GPU (Optional)
```powershell
\.\Configure-CUDA.ps1 -Enable
```
Note: TensorFlow GPU is not supported on Windows; use Docker or WSL for GPU workloads.

### 4. Operator consoles
- GUI (admin/operator): `powershell -ExecutionPolicy Bypass -File .\Deploy\PLM-Environment-AdminGUI.fixed.ps1`
- CLI parity: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --menu` (add `--curses` if you installed windows-curses)

### 5. Run Simulation
```bash
.\venv\Scripts\python.exe .\scripts\plm_cli.py --run-plm
```

### 6. View Results
The simulation outputs CSV data: t,S,theta,p1,expZ

## Key Commands

- **Start (menu)**: `powershell -ExecutionPolicy Bypass -File .\start_plm.ps1`
- **Enable CUDA**: `.\Configure-CUDA.ps1 -Enable`
- **Disable CUDA**: `.\Configure-CUDA.ps1 -Disable`
- **Run GUI**: `powershell -ExecutionPolicy Bypass -File .\Deploy\PLM-Environment-AdminGUI.fixed.ps1`
- **CLI Menu**: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --menu`
- **Smoke Test**: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --smoke`
- **Run PLM Simulation**: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --run-plm`
- **Run CLI console**: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --menu`
- **Run Sim**: `python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py`
- **Start menu options**: `start_plm.ps1` offers presets for Docker, CUDA, both, disable both, and silent monitor (GUI/CLI) modes; press Enter for the Admin GUI default.

## Troubleshooting

- No output? Check venv activation.
- GPU not working? Run `nvidia-smi` to verify CUDA.
- Errors? Ensure all dependencies installed.

## Security Note

- Scripts prompt for any required credentials at runtime; do not hardcode or commit tokens/passwords.
- Keep generated artifacts (especially autoinstall templates and logs) under `bak/` so they stay out of git.
- To run noninteractively, set `PLM_AUTH_TOKEN` (or `PLM_AUTH_TOKEN_FILE`) before invoking scripts. Details: [docs/auth.md](auth.md).