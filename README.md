PLM
===

Algorithms based via pi lambda mu calculation

The Base Algorithm for all of these projects is: PI multiplied by LAMBDA over MU (PLM).

Mathmatically if: Pi(P) , Lambda(L), and Mu(M)

Your baseline to solve NP hard would look simmilar to this if applied to an SSH/SSL scenario.

   {(P) by Y } by {(L) by X } over {(M) by C } = S

In this case Y is the hexadecimal value for the public key hash as a child of chain of authority hash, C is the crypted data's block size + the file crc hash string value in decimal (a sha1 or md5 hash converted to a decimal exponential will do as well), and S is the Secret/Private Key

## Getting started (local clone, x86-64 Cirq)
- Fast start (choose GUI or CLI): `powershell -ExecutionPolicy Bypass -File ./start_plm.ps1`
- Clone + install manually: `python -m venv venv && ./venv/Scripts/python.exe -m pip install -e ./Code_core_3/plm-formalized`
- Optional GPU sim: `./venv/Scripts/python.exe -m pip install qsimcirq`
- Smoke test (CI-like): `./venv/Scripts/python.exe test_installation.py`
- One-command local CI helper: `powershell -ExecutionPolicy Bypass -File ./scripts/local_ci.ps1` (add `-WithGPU` to install qsimcirq)
- Admin GUI (full operator console): `powershell -ExecutionPolicy Bypass -File ./Deploy/PLM-Environment-AdminGUI.fixed.ps1`
- CLI operator console (GUI parity): `./venv/Scripts/python.exe ./scripts/plm_cli.py --menu`
- CUDA toggle: `powershell -ExecutionPolicy Bypass -File ./Configure-CUDA.ps1 -Enable` (or `-Disable`)

This project targets Windows x86-64 with Python 3.9+ (tested on 3.12). Cirq runs CPU by default; if `qsimcirq` is installed and CUDA is enabled, GPU-backed simulation is used.

## Troubleshooting
- See [docs/Local-Troubleshooting.md](docs/Local-Troubleshooting.md) for diagnostics, logging, and common fixes.
- Quick start guides: [docs/Quick-Start-Guide.md](docs/Quick-Start-Guide.md) and [docs/Detailed-Install-Guide.md](docs/Detailed-Install-Guide.md).
- Operator consoles (GUI + CLI parity): [docs/Admin-GUI-and-CLI-Guide.md](docs/Admin-GUI-and-CLI-Guide.md)

## Security / Credentials

- This repository does not store credentials. Scripts that need tokens/password-hashes prompt at runtime.
- Do not commit generated artifacts that may include secrets or password hashes. By default, generated artifacts should be placed under `bak/` (ignored by git).
- Treat any CI logs, environment dumps, and installer/autoinstall output as sensitive.



