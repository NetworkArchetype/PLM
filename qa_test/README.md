# QA Test Scripts

This folder contains repeatable smoke/QA runners for PLM. They avoid interactivity where possible and can be invoked from CI or a fresh sandbox clone.

## Scripts

- `windows_cli_smoke.ps1`: Runs compile check, CLI env/probe/export, and `start_plm.ps1 -CLI -NonInteractive` with optional arguments. Automatically installs TensorFlow if missing unless `-InstallTensorflow:$false` is passed.
- `windows_sandbox_matrix.ps1`: Clones PLM into a temp sandbox and runs `windows_cli_smoke.ps1`; supports choosing Docker/CUDA test toggles.
- `linux_cli_smoke.sh`: Minimal Linux smoke (compile + CLI env/probe/export best-effort) for containers/WSL runners. Installs TensorFlow by default; set `INSTALL_TF=0` to skip.
- `scripts/auto_install_and_smoke.ps1`: Fully automated Windows path that creates a venv, installs PLM + TensorFlow GPU, then runs `windows_cli_smoke.ps1` (5s countdown by default).

Both smoke scripts now also verify TensorFlow availability (GPU build where present) and will install + re-check once by default; disable auto-install to treat missing TensorFlow as a hard failure.

## Quick usage

From repo root (PowerShell):
```powershell
pwsh -File qa_test/windows_cli_smoke.ps1
pwsh -File qa_test/windows_cli_smoke.ps1 -NonInteractive -ProbeCuda:$false
```

Sandbox clone + run:
```powershell
pwsh -File qa_test/windows_sandbox_matrix.ps1 -RepoUrl https://github.com/NetworkArchetype/PLM.git -IncludeDocker -IncludeCuda
```

Linux (bash):
```bash
bash qa_test/linux_cli_smoke.sh
```

## Dispatch QA workflow via `gh`

PowerShell helper (runs `gh workflow run` for `.github/workflows/qa-matrix.yml`):
```powershell
pwsh -File scripts/dispatch_qa_workflow.ps1 -Ref master -EnableCudaDocker -CudaDockerRunnerLabels '["windows-cuda","windows-cuda-docker"]'
```

Bash helper:
```bash
WORKFLOW_FILE=.github/workflows/qa-matrix.yml \
REF=master ENABLE_CUDA_DOCKER=true \
CUDA_DOCKER_RUNNER_LABELS='["windows-cuda","windows-cuda-docker"]' \
bash scripts/dispatch_qa_workflow.sh
```

Omit the CUDA/Docker flags to run only the hosted runners. Use `DRY_RUN=true` (bash) or `-DryRun` (PowerShell) to see the dispatch command without sending it.

## Auth tokens

All entry points honor `PLM_AUTH_TOKEN` (or `PLM_AUTH_TOKEN_FILE`) to avoid prompts in noninteractive runs. Interactive shells will prompt once per session and cache an encrypted copy under `%TEMP%\plm_session`.
More details: [docs/auth.md](../docs/auth.md)
