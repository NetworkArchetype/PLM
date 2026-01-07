#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_FILE=${WORKFLOW_FILE:-.github/workflows/qa-matrix.yml}
REF=${REF:-master}
ENABLE_CUDA_DOCKER=${ENABLE_CUDA_DOCKER:-false}
CUDA_DOCKER_RUNNER_LABELS=${CUDA_DOCKER_RUNNER_LABELS:-["windows-cuda","windows-cuda-docker"]}
REPO=${REPO:-}
DRY_RUN=${DRY_RUN:-false}

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required (https://cli.github.com/)" >&2
  exit 1
fi

cmd=(gh)
if [[ -n "$REPO" ]]; then
  cmd+=(--repo "$REPO")
fi
cmd+=(workflow run "$WORKFLOW_FILE" --ref "$REF" -f enableCudaDocker="$ENABLE_CUDA_DOCKER")
if [[ "$ENABLE_CUDA_DOCKER" == "true" ]]; then
  cmd+=(-f cudaDockerRunnerLabels="$CUDA_DOCKER_RUNNER_LABELS")
fi

echo "Dispatching: ${cmd[*]}"
if [[ "$DRY_RUN" == "true" ]]; then
  exit 0
fi

"${cmd[@]}"
