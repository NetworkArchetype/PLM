# PLM Quick Start Guide

## Get Started in 5 Minutes

### 1. Clone and Setup
```bash
git clone https://github.com/NetworkArchetype/PLM.git
cd PLM
python -m venv venv
.\venv\Scripts\activate
pip install -e .
pip install -e ".[quantum]"
```

### 2. Enable GPU (Optional)
```powershell
.\Configure-CUDA.ps1 -Enable
```

### 3. Run GUI
```powershell
.\PLM-Environment-AdminGUI.fixed.ps1
```

### 4. Run Simulation
```bash
python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py
```

### 5. View Results
The simulation outputs CSV data: t,S,theta,p1,expZ

## Key Commands

- **Enable CUDA**: `.\Configure-CUDA.ps1 -Enable`
- **Disable CUDA**: `.\Configure-CUDA.ps1 -Disable`
- **Run GUI**: `.\PLM-Environment-AdminGUI.fixed.ps1`
- **Run Sim**: `python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py`

## Troubleshooting

- No output? Check venv activation.
- GPU not working? Run `nvidia-smi` to verify CUDA.
- Errors? Ensure all dependencies installed.