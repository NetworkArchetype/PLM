param(
    [string]$WorkflowFile = ".github/workflows/qa-matrix.yml",
    [string]$Ref = "master",
    [switch]$EnableCudaDocker,
    [string]$CudaDockerRunnerLabels = '["windows-cuda","windows-cuda-docker"]',
    [string]$Repo,
    [switch]$DryRun
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh CLI is required (https://cli.github.com/)"
    exit 1
}

$repoArgs = @()
if ($Repo) {
    $repoArgs += "--repo"
    $repoArgs += $Repo
}

$cmd = @(
    "workflow", "run", $WorkflowFile,
    "--ref", $Ref,
    "-f", "enableCudaDocker=$($EnableCudaDocker.IsPresent.ToString().ToLower())"
)

if ($EnableCudaDocker) {
    $cmd += "-f"
    $cmd += "cudaDockerRunnerLabels=$CudaDockerRunnerLabels"
}

Write-Host "Dispatching: gh $($repoArgs + $cmd -join ' ')"
if ($DryRun) { exit 0 }

& gh @repoArgs @cmd
exit $LASTEXITCODE
