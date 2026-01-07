param(
  [switch]$CLI,
  [switch]$GUI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSCommandPath
$guiScript = Join-Path $repoRoot "Deploy/PLM-Environment-AdminGUI.fixed.ps1"
$cliScript = Join-Path $repoRoot "scripts/plm_cli.py"
$python = Join-Path $repoRoot "venv/Scripts/python.exe"
$hasVenv = Test-Path $python
if (-not $hasVenv) { $python = "python" }

function Launch-GUI {
  if (-not (Test-Path $guiScript)) { Write-Host "GUI script not found: $guiScript" -ForegroundColor Red; return }
  Write-Host "Launching Admin GUI..." -ForegroundColor Cyan
  Start-Process powershell.exe -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-STA","-File",$guiScript
}

function Launch-CLI {
  if (-not (Test-Path $cliScript)) { Write-Host "CLI script not found: $cliScript" -ForegroundColor Red; return }
  if (-not $hasVenv) {
    $resp = Read-Host "No venv detected. Run setup now (local_ci.ps1)? (y/n)"
    if ($resp -match '^[Yy]') {
      $withGpu = Read-Host "Install GPU extras (qsimcirq)? (y/n)"
      $args = @("-ExecutionPolicy","Bypass","-File", (Join-Path $repoRoot "scripts/local_ci.ps1"))
      if ($withGpu -match '^[Yy]') { $args += "-WithGPU" }
      Write-Host "Running setup..." -ForegroundColor Cyan
      & powershell @args
      $python = Join-Path $repoRoot "venv/Scripts/python.exe"
    }
  }
  Write-Host "Launching PLM CLI (operator console)..." -ForegroundColor Cyan
  & $python $cliScript --menu
}

if ($GUI -and -not $CLI) { Launch-GUI; exit }
if ($CLI -and -not $GUI) { Launch-CLI; exit }

# Default to GUI if no explicit choice is provided to avoid hanging on prompt when double-clicked
Write-Host "PLM start menu" -ForegroundColor Cyan
Write-Host "1) Admin GUI" -ForegroundColor Yellow
Write-Host "2) CLI console" -ForegroundColor Yellow
$choice = Read-Host "Select an option (1/2, Enter for GUI)"
switch ($choice) {
  ""  { Launch-GUI }
  "1" { Launch-GUI }
  "2" { Launch-CLI }
  default { Write-Host "No selection made." -ForegroundColor Red }
}
