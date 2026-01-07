# PLM Quick Start Guide

## Get Started in 5 Minutes

### 1. Fast start (GUI or CLI)
```powershell
powershell -ExecutionPolicy Bypass -File .\start_plm.ps1
```
Pick **Admin GUI** (full operator console) or **CLI console** (same actions from terminal).

### 2. Manual setup (if you prefer)
```bash
git clone https://github.com/NetworkArchetype/PLM.git
cd PLM
python -m venv venv
\.\venv\Scripts\activate
pip install -e .
pip install -e ".[quantum]"
```

Run the smoke test (verifies Cirq + PLM + quantum temporal path):

```bash
python test_installation.py
```

### 3. Enable GPU (Optional)
```powershell
\.\Configure-CUDA.ps1 -Enable
```

### 4. Operator consoles
- GUI (admin/operator): `powershell -ExecutionPolicy Bypass -File .\Deploy\PLM-Environment-AdminGUI.fixed.ps1`
- CLI parity: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --menu` (add `--curses` if you installed windows-curses)

### 5. Run Simulation
```bash
python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py
```

### 6. View Results
The simulation outputs CSV data: t,S,theta,p1,expZ

## Key Commands

- **Start (menu)**: `powershell -ExecutionPolicy Bypass -File .\start_plm.ps1`
- **Enable CUDA**: `\.\Configure-CUDA.ps1 -Enable`
- **Disable CUDA**: `\.\Configure-CUDA.ps1 -Disable`
- **Run GUI**: `\.\Deploy\PLM-Environment-AdminGUI.fixed.ps1`
- **Run CLI console**: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --menu`
- **Run Sim**: `python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py`

## Troubleshooting

- No output? Check venv activation.
- GPU not working? Run `nvidia-smi` to verify CUDA.
- Errors? Ensure all dependencies installed.

## Security Note

- Scripts prompt for any required credentials at runtime; do not hardcode or commit tokens/passwords.
- Keep generated artifacts (especially autoinstall templates and logs) under `bak/` so they stay out of git.