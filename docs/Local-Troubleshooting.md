# Local Troubleshooting and Diagnostics

Use this guide after cloning to verify the environment, capture logs, and diagnose issues.

## 1) Quick verify (CI-like smoke test)
1. Create venv and install:
   - `python -m venv venv`
   - `./venv/Scripts/python.exe -m pip install -e ./Code_core_3/plm-formalized`
   - Optional GPU: `./venv/Scripts/python.exe -m pip install qsimcirq`
2. Run the smoke test: `./venv/Scripts/python.exe test_installation.py`
   - Pass: shows Cirq/PLM imports, circuit stats, PLM values, and quantum temporal outputs.
   - Fail: messages point to missing packages or runtime issues; reinstall per step 1.

Fast path: `powershell -ExecutionPolicy Bypass -File ./scripts/local_ci.ps1` (add `-WithGPU` to pull qsimcirq). Bash users: `WITH_GPU=1 ./scripts/local_ci.sh`.

## 2) GUI + CLI checks
- Admin GUI: `powershell -ExecutionPolicy Bypass -File ./Deploy/PLM-Environment-AdminGUI.fixed.ps1`
  - Prompts/elevates as needed; logs redact passwords/tokens.
- CUDA toggle: `powershell -ExecutionPolicy Bypass -File ./Configure-CUDA.ps1 -Enable` (or `-Disable`).
- Quantum demo: `./venv/Scripts/python.exe Code_core_3/plm-formalized/quantum/run_quantum_temporal.py` (after install above).

## 3) Credentials and prompts (ephemeral)
- Upload scripts prompt for tokens if not provided: `scripts/upload_random_artifact.ps1` / `.sh`.
- Ventoy payload scripts prompt for Ubuntu password hashes at runtime: `Code_core_3/Engine_proof/make_ventoy_payload_win.ps1` and `drop_it.ps1`.
- Admin GUI logs are sanitized to avoid credential leakage.
- Use `.env.example` as a template for non-secret config; do not store secrets in repo.

## 4) Capturing logs
- PowerShell: append `| Tee-Object -FilePath .\bak\run.log` to keep output under `bak/` (gitignored).
- Python: `./venv/Scripts/python.exe test_installation.py > bak/test_installation.log`.
- GUI: take screenshots or copy the console output from the launch window if issues occur.

## 5) Common fixes
- Missing Cirq/PLM imports: reinstall with `pip install -e ./Code_core_3/plm-formalized`.
- GPU sim missing: install `qsimcirq` or run CPU-only (it falls back automatically).
- Execution policy blocks scripts: run PowerShell with `-ExecutionPolicy Bypass`.
- winget missing for CUDA script: install "App Installer" from Microsoft Store, then rerun.

## 6) Architecture notes (x86-64 Cirq env)
- Target: Windows x86-64 with Python 3.9+; tested on 3.12.
- Cirq/PLM runs CPU by default; qsimcirq enables GPU-backed simulation when available.
- CUDA toggles via `Configure-CUDA.ps1` update `cuda_config.json` for simulators.
