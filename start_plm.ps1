param(
  [switch]$CLI,
  [switch]$GUI,
  [switch]$NonInteractive,   # skip interactive prompts (useful for CI)
  [string[]]$CLIArgs         # optional args to pass to plm_cli.py when NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSCommandPath
$guiScript = Join-Path $repoRoot "Deploy/PLM-Environment-AdminGUI.fixed.ps1"
$cliScript = Join-Path $repoRoot "scripts/plm_cli.py"
$autoInstaller = Join-Path $repoRoot "scripts/auto_install_and_smoke.ps1"
$python = Join-Path $repoRoot "venv/Scripts/python.exe"
$hasVenv = Test-Path $python
if (-not $hasVenv) { $python = "python" }
$authHelper = Join-Path $repoRoot "scripts/auth_session.ps1"
if (Test-Path $authHelper) { . $authHelper }

function Ensure-AuthToken {
  param([string]$Mode = "CLI")
  if (-not (Get-Command Get-PlmAuthToken -ErrorAction SilentlyContinue)) { return }
  try {
    $token = Get-PlmAuthToken -Mode $Mode -NonInteractive:$NonInteractive -PromptTitle "PLM authentication required"
    $env:PLM_AUTH_TOKEN = $token
    $env:PLM_AUTH_HASH = Get-PlmAuthTokenHash
  } catch {
    Write-Host "Authentication required: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
}

function Invoke-GUI {
  if (-not (Test-Path $guiScript)) { Write-Host "GUI script not found: $guiScript" -ForegroundColor Red; return }
  Write-Host "Launching Admin GUI..." -ForegroundColor Cyan
  Ensure-AuthToken -Mode "GUI"
  Start-Process powershell.exe -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-STA","-File",$guiScript
}

function Invoke-CLI {
  param(
    [switch]$NonInteractive,
    [string[]]$Args
  )
  if (-not (Test-Path $cliScript)) { Write-Host "CLI script not found: $cliScript" -ForegroundColor Red; return }
  Ensure-AuthToken -Mode "CLI"
  if ($Args -and ($Args -isnot [System.Array])) { $Args = @($Args) }
  if (-not $hasVenv) {
    if ($NonInteractive) {
      Write-Host "No venv detected; skipping interactive setup (NonInteractive)." -ForegroundColor Yellow
      return
    }
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
  if ($NonInteractive) {
    $cliArgsEffective = if ($Args -and $Args.Count -gt 0) { $Args } else { @("--env") }
    if ($cliArgsEffective -isnot [System.Array]) { $cliArgsEffective = @($cliArgsEffective) }
    & $python $cliScript @($cliArgsEffective)
  } else {
    & $python $cliScript --menu
  }
}

function Invoke-AutoInstall {
  if (-not (Test-Path $autoInstaller)) { Write-Host "Auto installer not found: $autoInstaller" -ForegroundColor Red; return }
  Write-Host "Running fully automated install + TensorFlow + smoke tests..." -ForegroundColor Cyan
  & $autoInstaller
}

function Invoke-AutoInstallAdvanced {
  param(
    [switch]$PreferContainer,
    [switch]$ContainerOnly,
    [switch]$NativeOnly,
    [switch]$WithGPU,
    [switch]$NativeTF,
    [switch]$ContainerPLM
  )
  if (-not (Test-Path $autoInstaller)) { Write-Host "Auto installer not found: $autoInstaller" -ForegroundColor Red; return }
  Write-Host "Running automated install with custom flags..." -ForegroundColor Cyan
  $args = @()
  if ($PreferContainer) { $args += "-PreferContainer" }
  if ($ContainerOnly) { $args += "-ContainerOnly" }
  if ($NativeOnly) { $args += "-NativeOnly" }
  if (-not $WithGPU) { $args += "-WithGPU:`$false" }
  if ($NativeTF) { $args += "-NativeTF" }
  if ($ContainerPLM) { $args += "-ContainerPLM" }
  & $autoInstaller @args
}

function Read-ChoiceWithTimeout {
  param(
    [string]$Prompt,
    [int]$TimeoutSeconds = 5,
    [string]$Default = "0"
  )

  $job = Start-Job -ScriptBlock { param($p) Read-Host $p } -ArgumentList $Prompt
  $finished = Wait-Job $job -Timeout $TimeoutSeconds
  $result = $Default
  if ($finished) {
    $result = Receive-Job $job
  } else {
    Write-Host ""  # ensure prompt moves to next line
    Write-Host "No selection received in $TimeoutSeconds seconds. Defaulting to option $Default." -ForegroundColor Yellow
    Stop-Job $job -Force | Out-Null
  }
  Remove-Job $job -Force | Out-Null
  return $result
}

if ($GUI -and -not $CLI) { Invoke-GUI; exit }
if ($CLI -and -not $GUI) { Invoke-CLI -NonInteractive:$NonInteractive -Args:$CLIArgs; exit }

# Default to GUI if no explicit choice is provided to avoid hanging on prompt when double-clicked
Write-Host "PLM start menu" -ForegroundColor Cyan
Write-Host "0) Auto install + smoke (container preferred, native + container) [default in 5s]" -ForegroundColor Yellow
Write-Host "8) Auto install native-only (GPU required)" -ForegroundColor Yellow
Write-Host "9) Auto install container-only" -ForegroundColor Yellow
Write-Host "A) Advanced install (customize native/container/GPU)" -ForegroundColor Yellow
Write-Host "B) Auto-detect CUDA: native CUDA/TensorFlow if detected, disabled if not; Container PLM" -ForegroundColor Yellow
Write-Host "H) Help/Troubleshooting" -ForegroundColor Yellow
Write-Host "1) CLI with Docker support" -ForegroundColor Yellow
Write-Host "2) CLI with CUDA support" -ForegroundColor Yellow
Write-Host "3) CLI with Docker + CUDA checks" -ForegroundColor Yellow
Write-Host "4) CLI enable Docker + CUDA" -ForegroundColor Yellow
Write-Host "5) CLI with Docker/CUDA off" -ForegroundColor Yellow
Write-Host "6) GUI monitor install silently, then open terminal" -ForegroundColor Yellow
Write-Host "7) CLI monitor install silently, then open terminal" -ForegroundColor Yellow
Write-Host "(Enter for Admin GUI)" -ForegroundColor Yellow
if ($NonInteractive) {
  $choice = "0"
} else {
  $choice = Read-ChoiceWithTimeout -Prompt "Select an option" -TimeoutSeconds 5 -Default "0"
}
switch ($choice) {
  "0" { Invoke-AutoInstall }
  "8" { Invoke-AutoInstallAdvanced -NativeOnly -WithGPU }
  "9" { Invoke-AutoInstallAdvanced -ContainerOnly -PreferContainer }
  "A" { 
    $pref = Read-Host "Prefer container? (y/n) [y]"
    $contOnly = Read-Host "Container only? (y/n) [n]"
    $natOnly = Read-Host "Native only (requires CUDA/TF GPU)? (y/n) [n]"
    $withGpu = Read-Host "Install GPU extras (qsimcirq)? (y/n) [y]"
    if (($contOnly -match '^[Yy]') -and ($natOnly -match '^[Yy]')) {
      Write-Host "Cannot select both Container only and Native only. Please choose one or neither." -ForegroundColor Red
      continue
    }
    $args = @{}
    if ($pref -eq "" -or $pref -match '^[Yy]') { $args['PreferContainer'] = $true }
    if ($contOnly -match '^[Yy]') { $args['ContainerOnly'] = $true }
    if ($natOnly -match '^[Yy]') { $args['NativeOnly'] = $true }
    if ($withGpu -and $withGpu -notmatch '^[Yy]') { $args['WithGPU'] = $false }
    Invoke-AutoInstallAdvanced @args
  }
  "B" { Invoke-AutoInstallAdvanced -NativeTF -ContainerPLM }
  "H" { 
    Write-Host "PLM Installation Troubleshooting:" -ForegroundColor Cyan
    Write-Host "1. For native TensorFlow GPU issues:" -ForegroundColor Yellow
    Write-Host "   - Ensure NVIDIA GPU drivers are installed." -ForegroundColor White
    Write-Host "   - Install CUDA toolkit from https://developer.nvidia.com/cuda-downloads" -ForegroundColor White
    Write-Host "   - Restart after installing CUDA." -ForegroundColor White
    Write-Host "   - Check debug/native_detect.json for details." -ForegroundColor White
    Write-Host "2. For container issues:" -ForegroundColor Yellow
    Write-Host "   - Ensure Docker Desktop is running." -ForegroundColor White
    Write-Host "   - Enable WSL2 if on Windows." -ForegroundColor White
    Write-Host "   - Check debug/container_detect.json for GPU access." -ForegroundColor White
    Write-Host "3. For NUMA warnings in containers:" -ForegroundColor Yellow
    Write-Host "   - These are harmless on Windows; ignore them." -ForegroundColor White
    Write-Host "4. If issues persist, run option A for advanced customization." -ForegroundColor Yellow
    Read-Host "Press Enter to return to menu"
    continue
  }
  ""  { Invoke-GUI }
  "1" { Invoke-CLI -NonInteractive -Args @("--env","--ensure-docker","--export-report") }
  "2" { Invoke-CLI -NonInteractive -Args @("--env","--probe-cuda","--export-report") }
  "3" { Invoke-CLI -NonInteractive -Args @("--env","--ensure-docker","--probe-cuda","--export-report") }
  "4" { Invoke-CLI -NonInteractive -Args @("--env","--ensure-docker","--probe-cuda","--enable-cuda","--export-report") }
  "5" { Invoke-CLI -NonInteractive -Args @("--env","--disable-cuda","--export-report") }
  "6" { Invoke-GUI; Start-Process powershell.exe -ArgumentList "-NoProfile" }
  "7" { & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts/local_ci.ps1"); Start-Process powershell.exe -ArgumentList "-NoProfile" }
  default { Write-Host "No valid selection made." -ForegroundColor Red }
}
