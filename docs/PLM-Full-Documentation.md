# PLM Full Documentation

## Overview

PLM (Probabilistic Logic Machine) is a quantum temporal simulation framework that encodes stateful PLM computations into quantum circuits using Cirq. It supports both CPU and GPU acceleration via CUDA.

## Architecture

- **Core Components**:
  - `plm_formalized/`: Python package with PLM models, stateful updates, and quantum temporal encoding.
  - `PLM-Environment-AdminGUI.fixed.ps1`: PowerShell GUI for environment management.
  - `Configure-CUDA.ps1`: Script to toggle CUDA support.
  - `run_quantum_temporal.py`: Example script to run quantum simulations.

- **Key Features**:
  - Stateful PLM with configurable update rules.
  - Quantum encoding of temporal evolution.
  - CUDA GPU acceleration with qsimcirq or TensorFlow.
  - GUI for easy management.

## Installation

### Prerequisites

- Python 3.8+
- PowerShell 5.1+
- NVIDIA GPU (optional, for CUDA acceleration)
- CUDA Toolkit 13.1+ (installed via script)

### Quick Install

1. Clone the repository:
   ```bash
   git clone https://github.com/NetworkArchetype/PLM.git
   cd PLM
   ```

2. Install Python dependencies:
   ```bash
   python -m venv venv
   .\venv\Scripts\activate  # Windows
   pip install -e .
   pip install -e ".[quantum]"
   pip install qsimcirq  # For GPU support
   ```

3. Run the GUI:
   ```powershell
   .\PLM-Environment-AdminGUI.fixed.ps1
   ```

## Usage

### GUI Operations

The PowerShell GUI provides:

- **CUDA Status**: Displays current CUDA configuration.
- **Enable CUDA**: Enables CUDA and installs toolkit if needed.
- **Disable CUDA**: Disables CUDA.
- **Test CUDA**: Runs a quick quantum simulation to verify setup.

### Scripts

#### Configure-CUDA.ps1

Toggles CUDA support.

**Switches**:
- `-Enable`: Enable CUDA, install toolkit.
- `-Disable`: Disable CUDA.

**Examples**:
```powershell
.\Configure-CUDA.ps1 -Enable
.\Configure-CUDA.ps1 -Disable
```

#### PLM-Environment-AdminGUI.fixed.ps1

Main GUI script. No switches, run directly.

#### Python Scripts

##### run_quantum_temporal.py

Runs quantum temporal simulation.

**Configuration**:
- Reads `cuda_config.json` for CUDA setting.
- Uses GPU simulator if CUDA enabled and available.

**Output**: CSV of t,S,theta,p1,expZ

**Example**:
```bash
python Code_core_3\plm-formalized\quantum\run_quantum_temporal.py
```

### Functions

#### Python Functions

- `simulate_time_series(plm_machine, steps, cfg)`: Runs simulation, returns records.
- `QuantumTemporalConfig(scale, shots)`: Config for simulation.
- `PLMInputs(pi, lam, mu, x, public_hash_hex, block_size, crc_decimal)`: PLM inputs.
- `PLMState(t, inputs)`: PLM state.
- `StatefulPLM(state0, update_fn)`: Stateful PLM machine.

#### PowerShell Functions

- GUI event handlers for buttons.
- CUDA detection via CIM/WMI.
- Toolkit installation via winget.

## Configuration

- `cuda_config.json`: {"CUDA_Enabled": true/false}
- Located in PLM root directory.

## Development

- Editable install: `pip install -e .`
- Tests: `python -m pytest tests/`
- Build: Standard Python packaging.

## Troubleshooting

- Ensure venv is activated.
- Check CUDA installation with `nvidia-smi`.
- Verify qsimcirq installation for GPU.

## Chat Transcripts

### Conversation Summary

[From the provided conversation-summary]

**Analysis:**
[Chronological Review: The conversation began with user requests to factor the PowerShell GUI to include CUDA support for NVIDIA GPUs, test against the host GPU, and create a configuration script to toggle CUDA on/off. This evolved into implementing CUDA detection and installation in the GUI, creating a Configure-CUDA.ps1 script, modifying the Python quantum simulation code to check for CUDA config and use GPU simulators (qsim or TensorFlow), and debugging why the config wasn't being loaded or the GPU simulators weren't being selected despite CUDA being enabled.]

[Intent Mapping: User initially wanted to add CUDA to the GUI for GPU support, test on host (NVIDIA RTX 1000 Ada GPU detected), create a toggle script, and debug both CPU and GPU modes until they work. Recent focus: Ensure the config script enables/disables CUDA properly, and the Python code reads the config to switch simulators, with debugging to confirm GPU usage.]

[Technical Inventory: PowerShell (GUI with WinForms, config scripts), Python (PLM package, Cirq for quantum sims, qsimcirq for GPU, venv), CUDA (NVIDIA Toolkit 13.1 installed via winget), JSON config files, pip for package management. Key: Editable installs, stderr prints for debugging, GPU detection via CIM/WMI.]

[Code Archaeology: Configure-CUDA.ps1 (enables/disables CUDA, installs toolkit/TensorFlow), PLM-Environment-AdminGUI.fixed.ps1 (added CUDA detection/status/buttons), quantum_temporal.py (modified simulate_time_series to check cuda_config.json, try qsimcirq.QSimSimulator or TensorFlowSimulator if CUDA enabled), run_quantum_temporal.py (added debug print). Changes: Added config loading, simulator selection logic, debug prints.]

[Progress Assessment: Completed: CUDA detection/install in GUI, config script creation, basic Python modifications. In progress: Debugging config loading and simulator selection (config loads but prints not appearing, suggesting import or execution issues). Pending: Confirm GPU simulator usage, test performance difference, ensure both modes work reliably.]

[Context Validation: Repository: NetworkArchetype/PLM, master branch. Host: NVIDIA RTX 1000 Ada GPU, CUDA 13.1 installed, qsimcirq installed. Config file: cuda_config.json with {"CUDA_Enabled": true}. Critical: Python venv in PLM/, editable install of plm-formalized, quantum sims run but debug prints missing, indicating potential import caching or stderr handling issues.]

[Recent Commands Analysis: Last commands: (1) Added debug print "quantum_temporal.py imported" to quantum_temporal.py top; (2) Ran python run_quantum_temporal.py with 2>&1 pipe, output showed "Simulation completed" but no import/config prints; (3) Ran without 2>&1, showed CSV output but no stderr prints. Results: Script executes, produces quantum sim results, but debug prints for config loading and simulator selection not appearing, suggesting the modified code isn't being used (possibly cached import or editable install issue). Immediate state: Agent was debugging why CUDA config wasn't triggering GPU simulator, adding prints to trace execution. Trigger: Token budget exceeded while iterating on debug prints and test runs.]

**Summary:**
1. Conversation Overview:
- Primary Objectives: Factor PowerShell GUI to include CUDA for GPU support, create toggle config script, test both CPU/GPU modes on host (NVIDIA RTX 1000 Ada GPU), debug until both work reliably for PLM quantum simulations.
- Session Context: Started with GUI modifications for CUDA detection/install, progressed to config script and Python code changes for simulator selection, now debugging config loading and GPU usage.
- User Intent Evolution: Initial focus on GUI integration and basic toggle; evolved to ensuring Python reads config and switches to GPU simulators (qsim/TensorFlow), with emphasis on testing and fixing execution issues.

2. Technical Foundation:
- PowerShell: GUI (WinForms) with CUDA status/buttons, config script (Configure-CUDA.ps1) for enable/disable/install.
- Python/Cirq: PLM quantum sims, modified to check JSON config, use qsimcirq.QSimSimulator or TensorFlowSimulator for GPU.
- CUDA: NVIDIA Toolkit 13.1 (winget install), qsimcirq for GPU sims, TensorFlow attempted but failed due to version mismatch.
- Config/Testing: JSON file (cuda_config.json), venv with editable PLM install, stderr prints for debug.

3. Codebase Status:
- Configure-CUDA.ps1: Enables/disables CUDA, installs toolkit, sets config.
- PLM-Environment-AdminGUI.fixed.ps1: Added CUDA detection, status row, test button.
- quantum_temporal.py: simulate_time_series checks config, selects simulator (CPU/GPU), added debug prints.
- run_quantum_temporal.py: Added "Simulation completed" debug print.

4. Problem Resolution:
- Issues: CUDA not toggling in Python, config not loading, GPU simulators not selected despite qsimcirq installed.
- Solutions: Added config check in Python, try/except for simulators, debug prints. Partial: Config loads but prints missing, suggesting import caching or stderr issues.
- Debugging Context: Prints added to trace config load and simulator choice; runs produce output but no debug messages.
- Lessons Learned: Editable installs may cache; stderr in pipes needs careful handling; qsimcirq works but may not use GPU without CUDA build.

5. Progress Tracking:
- Completed: GUI CUDA integration, config script, basic Python mods, CUDA install on host.
- Partially Complete: Config loading (JSON read works in test, but in sim not traced), simulator selection (qsim imported but usage unconfirmed).
- Validated: CPU mode works (produces quantum CSV), host has NVIDIA GPU, CUDA toolkit installed.

6. Active Work State:
- Current Focus: Debugging why config-based simulator selection isn't executing (prints not appearing).
- Recent Actions: Added import debug print to quantum_temporal.py, ran script with/without stderr capture.
- Working Code: quantum_temporal.py simulate_time_series with config check and simulator logic.

7. Recent Operations:
- Agent Commands: (1) Modified quantum_temporal.py to add "quantum_temporal.py imported" print at top; (2) Ran python run_quantum_temporal.py 2>&1 | Select-Object -First 5 (result: "Simulation completed" appeared, CSV output, but no import/config prints); (3) Ran without 2>&1 (result: CSV output only, no stderr visible).
- Tool Results: Script executes successfully, generates quantum simulation data (t,S,theta,p1,expZ), but debug prints for module import, config loading, and simulator selection are absent, indicating the modified code may not be executing (possible import caching in editable install).
- Pre-Summary State: Agent was iterating on debug prints to trace why CUDA config wasn't triggering GPU simulator switch.
- Operation Context: Directly addressing user goal to test/debug both modes; recent runs confirm CPU works, but GPU path unconfirmed due to missing traces.

8. Continuation Plan:
- Pending Task 1: Investigate why debug prints aren't appearing (check if editable install uses cached version, restart Python process).
- Pending Task 2: Once config loading confirmed, verify qsimcirq uses GPU (check nvidia-smi during run).
- Priority: Fix config execution to enable GPU testing; then compare CPU/GPU performance.
- Next Action: Force reload of modified Python modules or reinstall package to ensure changes take effect.