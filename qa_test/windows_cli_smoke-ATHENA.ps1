param(
  [string]$RepoRoot,
  [switch]$NonInteractive = $true,
  [switch]$ProbeCuda = $true,
  [string[]]$CliArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
