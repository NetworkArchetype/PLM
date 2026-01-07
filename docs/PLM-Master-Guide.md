# PLM Master Guide

Use this as the hub; export to PDF if needed.

## Documents
- Install: docs/Install-Guide.md
- Quick start: docs/Quick-Start.md
- CUDA: docs/CUDA-Guide.md
- TensorFlow GPU: docs/TensorFlow-GPU-Guide.md
- Admin GUI: docs/Admin-GUI-Guide.md
- Existing full docs: docs/PLM-Full-Documentation.md

## Suggested reading order
1) Quick-Start.md
2) Install-Guide.md
3) CUDA-Guide.md and TensorFlow-GPU-Guide.md (GPU users)
4) Admin-GUI-Guide.md
5) PLM-Full-Documentation.md for deeper context

## PDF export
- From VS Code: use Markdown PDF extension or browser print-to-PDF for each guide.
- Combine via any PDF merger if a single file is needed.

## Operational notes
- Prefer CLI for scripted installs (`scripts/plm_cli.py`).
- Use Docker/WSL for reliable GPU TensorFlow; Windows host GPU install may hit missing `nvidia-nccl-cu12` wheels.
- Logs: .plm_session.ndjson records CLI/GUI actions.
