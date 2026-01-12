param(
  [string]$RepoRoot,
  [switch]$NonInteractive = $true,
  [switch]$ProbeCuda = $true,
  [switch]$InstallTensorflow = $true,
  [string[]]$CliArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tfProbeScript = @"
import sys, json, importlib
try:
    tf = importlib.import_module('tensorflow')
    info = {'version': tf.__version__, 'gpus': [d.name for d in tf.config.list_physical_devices('GPU')]}
    print(json.dumps(info))
    sys.exit(0)
except Exception as e:
    sys.stderr.write(f"TF_NOT_READY {e}\n")
    sys.exit(1)
"@

function Invoke-TensorFlowProbe {
  param([string]$PythonPath)
  $prevEAP = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $LASTEXITCODE = 0
    $info = & $PythonPath -c $tfProbeScript 2>$null
    return @{ Exit = $LASTEXITCODE; Info = $info }
  } finally {
    $ErrorActionPreference = $prevEAP
  }
}

if (-not $RepoRoot) {
  $RepoRoot = Split-Path -Parent $PSCommandPath
}

Push-Location $RepoRoot
try {
  Write-Host "[QA] Repo root: $RepoRoot" -ForegroundColor Cyan

  $python = Join-Path $RepoRoot "venv/Scripts/python.exe"
  if (-not (Test-Path $python)) { $python = "python" }

  Write-Host "[QA] Compile check" -ForegroundColor Yellow
  & $python -m compileall scripts/plm_cli.py

  Write-Host "[QA] CLI env" -ForegroundColor Yellow
  & $python scripts/plm_cli.py --log-level debug --env

  if ($ProbeCuda) {
    Write-Host "[QA] CLI probe-cuda" -ForegroundColor Yellow
    try { & $python scripts/plm_cli.py --log-level debug --probe-cuda --export-report } catch { Write-Warning "probe-cuda failed: $($_.Exception.Message)" }
  } else {
    & $python scripts/plm_cli.py --log-level debug --export-report
  }

  Write-Host "[QA] TensorFlow GPU check" -ForegroundColor Yellow
  $tfProbe = Invoke-TensorFlowProbe -PythonPath $python
  $tfExit = $tfProbe.Exit
  $tfInfo = $tfProbe.Info
  if ($tfExit -eq 0 -and $tfInfo) { Write-Host $tfInfo }
  if ($tfExit -ne 0) {
    if ($InstallTensorflow) {
      Write-Host "[QA] TensorFlow missing, installing..." -ForegroundColor Yellow
      & $python scripts/plm_cli.py --install-tf-gpu
      Write-Host "[QA] Re-checking TensorFlow..." -ForegroundColor Yellow
      $tfProbe = Invoke-TensorFlowProbe -PythonPath $python
      $tfExit = $tfProbe.Exit
      $tfInfo = $tfProbe.Info
      if ($tfExit -eq 0 -and $tfInfo) { Write-Host $tfInfo }
      if ($tfExit -ne 0) { Write-Error "TensorFlow still not ready after install"; exit 1 }
    } else {
      Write-Error "TensorFlow not ready (install with plm_cli --install-tf-gpu)"; exit 1
    }
  }

  $args = @()
  if ($CliArgs) { $args = $CliArgs } elseif ($ProbeCuda) { $args = @("--env","--probe-cuda","--export-report") } else { $args = @("--env","--export-report") }

  Write-Host "[QA] start_plm.ps1 -CLI" -ForegroundColor Yellow
  $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
  $startArgs = @("-ExecutionPolicy","Bypass","-File","start_plm.ps1","-CLI")
  if ($NonInteractive) { $startArgs += "-NonInteractive" } else { $startArgs += "-NonInteractive:",$false }
  if ($args) { $startArgs += "-CLIArgs"; $startArgs += $args }
  & $shell @startArgs

  Write-Host "[QA] done" -ForegroundColor Green
} finally {
  Pop-Location
}
