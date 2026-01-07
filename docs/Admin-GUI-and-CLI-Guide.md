# PLM Operator Consoles (GUI + CLI)

This guide covers the Admin GUI and the CLI operator console. Both provide the same controls for students, operators, and advanced users.

## Quick start
- Start menu (choose GUI or CLI):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\start_plm.ps1
  ```
- Direct GUI: `powershell -ExecutionPolicy Bypass -File .\Deploy\PLM-Environment-AdminGUI.fixed.ps1`
- Direct CLI: `.\venv\Scripts\python.exe .\scripts\plm_cli.py --menu`
- Optional curses UI (install `windows-curses` first): `... plm_cli.py --curses`
- If no venv is present, `start_plm.ps1` can run `scripts/local_ci.ps1` for you (optionally with GPU extras).

## Feature parity (GUI and CLI)
- Detect environment (winget/git/python/VS Code/WT/WSL/Docker/Hyper-V/nvidia-smi/nvcc)
- Install/Repair components (winget: Git, Python 3.12, VS Code, Windows Terminal, Docker Desktop, Nvidia CUDA)
- Update components (winget upgrade)
- Run smoke test (`test_installation.py`) and full pytest suite
- Probe CUDA/GPU (nvidia-smi, nvcc)
- Toggle CUDA via `Configure-CUDA.ps1` (enable/disable)
- Launch Admin GUI (from CLI) or open debug consoles (with/without venv)
- Export debug report (temp log)

## GUI walkthrough
- **Environment Detection**: status rows for winget/git/python/VS Code/WT/WSL/Ubuntu/Docker/Hyper-V/nvidia-smi/CUDA (nvcc)
- **Actions & Modes**: Detect, Install/Repair, Update, Run Deploy Script, terminal shortcuts (Admin PS, WSL, WT, Docker bash), Hyper-V links
- **Diagnostics & Debug**:
  - User mode: Guided (easy) vs Advanced debug (option 2)
  - Buttons: smoke test, full pytest, CUDA probe, refresh env report
  - Consoles: debug console, venv/option 2 console
  - Export debug report; open Windows Resource Monitor
  - Log level: toggle Normal/Debug logging (also available in CLI via `--log-level debug` or `--log-debug`)
- **Log Pane**: live output with secret redaction

## CLI walkthrough
- Menu options mirror GUI actions:
  1. Detect environment
  2. Run smoke test
  3. Run full pytest
  4. Probe CUDA/GPU
  5. Enable CUDA
  6. Disable CUDA
  7. Install/Repair components
  8. Update components
  9. Launch Admin GUI
  10. Open debug console
  11. Open option 2 console (venv)
  12. Export debug report
  0. Exit
- Flags for one-shot actions (examples):
  - `--env`, `--smoke`, `--pytest`, `--probe-cuda`
  - `--enable-cuda`, `--disable-cuda`
  - `--install-repair`, `--update-components`
  - `--launch-gui`, `--debug-console`, `--venv-console`, `--export-report`
  - `--log-level normal|debug` (or `--log-debug` shortcut)
  - `--menu` (default), `--curses`

## Tips
- Use Guided mode (GUI) for quick checks; switch to Advanced to unlock full pytest and venv console.
- For curses UI on Windows, install `windows-curses` in the venv.
- Run `scripts/local_ci.ps1 -WithGPU` if you want an all-in-one setup plus smoke test.
- Keep `cuda_config.json` under repo root; `Configure-CUDA.ps1` maintains it.
