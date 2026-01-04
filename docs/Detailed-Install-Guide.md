# PLM Detailed Installation Guide

## System Requirements

- **OS**: Windows 10/11 with PowerShell 5.1+
- **Python**: 3.8 or higher
- **Hardware**: 
  - CPU: Any modern x64 processor
  - RAM: 4GB minimum, 8GB recommended
  - GPU: NVIDIA GPU with CUDA support (optional, for acceleration)
- **Software**:
  - Git
  - Winget (for CUDA toolkit installation)

## Step-by-Step Installation

### 1. Clone Repository
```bash
git clone https://github.com/NetworkArchetype/PLM.git
cd PLM
```

### 2. Create Virtual Environment
```bash
python -m venv venv
.\venv\Scripts\activate
```

### 3. Install Core Dependencies
```bash
pip install -e .
```

### 4. Install Quantum Dependencies
```bash
pip install -e ".[quantum]"
```

### 5. Install GPU Support (Optional)
```bash
pip install qsimcirq
```

### 6. Configure CUDA (Optional)
```powershell
.\Configure-CUDA.ps1 -Enable
```
This will:
- Install NVIDIA CUDA Toolkit 13.1 via winget
- Create `cuda_config.json` with `{"CUDA_Enabled": true}`

### 7. Verify Installation
```bash
python -c "import plm_formalized; print('PLM installed')"
python -c "import cirq; print('Cirq installed')"
python -c "import qsimcirq; print('QSim installed')"  # If GPU enabled
```

## GUI Setup

### Running the Admin GUI
```powershell
.\PLM-Environment-AdminGUI.fixed.ps1
```

### GUI Features
- **CUDA Status Display**: Shows current configuration
- **Enable CUDA Button**: Enables CUDA support
- **Disable CUDA Button**: Disables CUDA support
- **Test CUDA Button**: Runs test simulation

## Script Details

### Configure-CUDA.ps1 Switches

- `-Enable`: Enables CUDA, installs toolkit if missing
- `-Disable`: Disables CUDA, updates config

**Examples**:
```powershell
# Enable with toolkit install
.\Configure-CUDA.ps1 -Enable

# Disable
.\Configure-CUDA.ps1 -Disable
```

### PLM-Environment-AdminGUI.fixed.ps1

No switches. Run directly:
```powershell
.\PLM-Environment-AdminGUI.fixed.ps1
```

## Python Package Details

### Installation Modes
- **Editable**: `pip install -e .` (recommended for development)
- **Regular**: `pip install .`

### Dependencies
- `cirq`: Quantum circuit simulation
- `qsimcirq`: GPU acceleration (optional)
- `tensorflow`: Alternative GPU backend (optional)
- `sympy`: Symbolic math
- `decimal`: High-precision arithmetic

### Package Structure
```
plm_formalized/
├── __init__.py
├── model.py          # PLM secret value functions
├── stateful.py       # Stateful PLM and updates
├── quantum_temporal.py  # Quantum encoding and simulation
└── quantum/
    └── run_quantum_temporal.py  # Example script
```

## Configuration Files

### cuda_config.json
```json
{
  "CUDA_Enabled": true
}
```
- Location: PLM root directory
- Auto-created by Configure-CUDA.ps1
- Read by quantum_temporal.py for simulator selection

## Testing Installation

### Run Basic Simulation
```bash
python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py
```

Expected output:
```
Simulation completed
t,S,theta,p1,expZ
0,0.00121144,...,1.000000
...
```

### Verify GPU Usage
```bash
nvidia-smi
```
Look for Python process using GPU memory.

### Run Tests
```bash
python -m pytest tests/
```

## Troubleshooting

### Common Issues

1. **ModuleNotFoundError**
   - Ensure venv is activated
   - Reinstall: `pip install -e .`

2. **CUDA Not Detected**
   - Run `nvidia-smi` to check GPU
   - Re-enable: `.\Configure-CUDA.ps1 -Enable`

3. **GUI Won't Start**
   - Check PowerShell execution policy
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

4. **Simulation Errors**
   - Check dependencies: `pip list`
   - Verify config: `type cuda_config.json`

### Logs and Debugging
- GUI logs errors to console
- Python uses stderr for debug info
- Check `nvidia-smi` during GPU runs

## Advanced Configuration

### Custom Simulator Selection
Modify `quantum_temporal.py` simulate_time_series() to change simulator logic.

### Performance Tuning
- Increase `shots` in QuantumTemporalConfig for better statistics
- Adjust `scale` for theta mapping
- Use GPU for large simulations

### Development Setup
```bash
pip install -e ".[dev]"  # If dev extras defined
pre-commit install  # If hooks configured
```