# PLM

Algorithms based via pi lambda mu calculation

The Base Algorithm for all of these projects is: PI multiplied by LAMBDA over MU (PLM).

Mathmatically if: Pi(P) , Lambda(L), and Mu(M)

Your baseline to solve NP hard would look simmilar to this if applied to an SSH/SSL scenario.

   {(P) by Y } by {(L) by X } over {(M) by C } = S

In this case Y is the hexadecimal value for the public key hash as a child of chain of authority hash, C is the crypted data's block size + the file crc hash string value in decimal (a sha1 or md5 hash converted to a decimal exponential will do as well), and S is the Secret/Private Key

## Getting started (local clone, x86-64 Cirq)

- Fully autonomous install + smoke (TensorFlow + Torch; GPU where available, default after 5s): `powershell -ExecutionPolicy Bypass -File ./start_plm.ps1` and let it auto-select option 0, or run `powershell -ExecutionPolicy Bypass -File ./scripts/auto_install_and_smoke.ps1`
- Fast start (choose GUI or CLI): `powershell -ExecutionPolicy Bypass -File ./start_plm.ps1`
- Clone + install manually: `python -m venv venv && ./venv/Scripts/python.exe -m pip install -e ./Code_core_3/plm-formalized`
- Install recommended ML stack (TensorFlow + Torch, plus best-effort CuPy when CUDA is present): `./venv/Scripts/python.exe ./scripts/plm_cli.py --install-tf-gpu`
- Optional GPU sim: `./venv/Scripts/python.exe -m pip install qsimcirq`
- Smoke test (CI-like): `./venv/Scripts/python.exe test_installation.py`
- One-command local CI helper: `powershell -ExecutionPolicy Bypass -File ./scripts/local_ci.ps1` (add `-WithGPU` to install qsimcirq)
- Admin GUI (full operator console): `powershell -ExecutionPolicy Bypass -File ./Deploy/PLM-Environment-AdminGUI.fixed.ps1`
- CLI operator console (GUI parity): `./venv/Scripts/python.exe ./scripts/plm_cli.py --menu`
- Start menu presets: `start_plm.ps1` includes options 0 (autonomous TF GPU), 8 (native-only GPU), 9 (container-only), A (advanced), B (auto-detect CUDA: native if detected, disabled if not; container PLM), H (Help); Enter defaults to Admin GUI.
- CUDA toggle: `powershell -ExecutionPolicy Bypass -File ./Configure-CUDA.ps1 -Enable` (or `-Disable`)

This project targets Windows x86-64 with Python 3.9+ (tested on 3.12). Cirq runs CPU by default; if `qsimcirq` is installed and CUDA is enabled, the project will attempt GPU-backed simulation and fall back gracefully if the installed qsim build does not include GPU support. Note: TensorFlow GPU is not supported natively on Windows; TensorFlow installs as CPU-only on Windows.

## Troubleshooting

- See [docs/Local-Troubleshooting.md](docs/Local-Troubleshooting.md) for diagnostics, logging, and common fixes.
- Quick start guides: [docs/Quick-Start-Guide.md](docs/Quick-Start-Guide.md) and [docs/Detailed-Install-Guide.md](docs/Detailed-Install-Guide.md).
- Operator consoles (GUI + CLI parity): [docs/Admin-GUI-and-CLI-Guide.md](docs/Admin-GUI-and-CLI-Guide.md)

## Documentation

- [PLM Full Documentation](docs/PLM-Full-Documentation.md)
- [PLM Master Guide](docs/PLM-Master-Guide.md)
- [Admin GUI Guide](docs/Admin-GUI-Guide.md)
- [CUDA Guide](docs/CUDA-Guide.md)
- [TensorFlow GPU Guide](docs/TensorFlow-GPU-Guide.md)
- [Authentication Guide](docs/auth.md)
- [Chat Transcripts](docs/Chat-Transcripts.md)
- [Quick Start](docs/Quick-Start.md)
- [Install Guide](docs/Install-Guide.md)

## PLM Proof Thesis (PROOF_PLM/)

Complete academic thesis with mathematical proofs, quantum verification, and cross-language validation. Click any chapter to read the rendered HTML:

| Chapter | Title |
|---------|-------|
| [Title Page & Abstract](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/index.html) | Title, abstract, table of contents |
| [Ch 1 — Introduction](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter1.html) | PLM definition, notation, scope |
| [Ch 2 — Mathematical Proofs](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter2.html) | 6 algebraic theorems |
| [Ch 3 — Implementation](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter3.html) | Python & Ruby code analysis |
| [Ch 4 — Empirical Validation](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter4.html) | Statistical results & error analysis |
| [Ch 5 — Quantum Integration](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter5.html) | Cirq circuits, Bell state, Grover |
| [Ch 6 — NP-Hard Benchmarks](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter6.html) | Grover 3-SAT, benchmark results |
| [Ch 7 — Conclusions](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/chapter7.html) | Summary of evidence, future work |
| [Appendix](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/appendix.html) | Full source listings & raw data |
| [Complete Thesis (single page)](https://htmlpreview.github.io/?https://github.com/ISBC8SYN/PLM_APLIED/blob/master/PROOF_PLM/combined_thesis.html) | All chapters combined |

**Proof runners:** Python (9/9 PASS), Ruby (9/9 PASS), Cirq quantum (5/5 PASS).
See [PROOF_PLM/README.md](PROOF_PLM/README.md) for full details, quick-start commands, and the downloadable ZIP.

## Security / Credentials

- This repository does not store credentials. Scripts that need tokens/password-hashes prompt at runtime.
- Do not commit generated artifacts that may include secrets or password hashes. By default, generated artifacts should be placed under `bak/`.
- Treat any CI logs, environment dumps, and installer/autoinstall output as sensitive.
- For noninteractive runs, set `PLM_AUTH_TOKEN` (or `PLM_AUTH_TOKEN_FILE`) to skip prompts. See [docs/auth.md](docs/auth.md) for details on prompts, hashing, and session cache.



