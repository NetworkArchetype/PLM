[CmdletBinding()]
param(
  [int]$AutoStartSeconds = 5,
  [switch]$SkipCountdown,
  [switch]$WithGPU = $true,
  [switch]$PreferContainer = $true,
  [switch]$ContainerOnly,
  [switch]$NativeOnly,
  [switch]$NativeTF,
  [switch]$ContainerPLM
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pyVenv = Join-Path $repoRoot "venv/Scripts/python.exe"
$detectScript = Join-Path $repoRoot "scripts/detect_gpu.py"
$debugDir = Join-Path $repoRoot "debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir | Out-Null }

function Step {
  param([string]$Name, [ScriptBlock]$Body)
  Write-Host "[STEP] $Name" -ForegroundColor Cyan
  try {
    $global:LASTEXITCODE = 0
    & $Body
    $bodySuccess = $?
    $exitCode = $LASTEXITCODE
    if (-not $bodySuccess -and $exitCode -eq 0) { $exitCode = 1 }
    if ($exitCode -ne 0) { throw "Exit code $exitCode" }
    Write-Host "[OK] $Name" -ForegroundColor Green
    return $true
  } catch {
    Write-Host "[FAIL] $Name :: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Countdown([int]$Seconds) {
  for ($i = $Seconds; $i -gt 0; $i--) {
    Write-Host ("Auto-starting in {0}s..." -f $i) -ForegroundColor Yellow
    Start-Sleep -Seconds 1
  }
  Write-Host ""
}

function Get-Python {
  if (Test-Path $pyVenv) { return $pyVenv }
  return "python"
}

if (-not $SkipCountdown -and $AutoStartSeconds -gt 0) {
  Write-Host "Starting fully automated install + TensorFlow + smoke run." -ForegroundColor Yellow
  Countdown $AutoStartSeconds
}

$python = Get-Python
$results = @()
$nativeOk = $false
$containerOk = $false
$containerPlmOk = $false

if ($ContainerOnly) { $NativeOnly = $false }
if ($NativeOnly) { $PreferContainer = $false; $ContainerOnly = $false }
if ($NativeTF) { $WithGPU = $true; $PreferContainer = $false; $ContainerOnly = $false; $NativeOnly = $false }
if ($ContainerPLM) { $PreferContainer = $true; $ContainerOnly = $false; $NativeOnly = $false }

$results += Step -Name "Ensure venv" -Body { if (-not (Test-Path $pyVenv)) { & $python -m venv (Join-Path $repoRoot "venv") } }
$python = Get-Python

if (-not $ContainerPLM) {
  $results += Step -Name "Upgrade pip" -Body { & $python -m pip install --upgrade pip setuptools wheel }
  if (-not $NativeTF) {
    $results += Step -Name "Install PLM editable" -Body { & $python -m pip install -e (Join-Path $repoRoot "Code_core_3/plm-formalized") }

    if ($WithGPU) {
      $results += Step -Name "Install qsimcirq (GPU optional)" -Body { & $python -m pip install qsimcirq }
    }
  }

  if (-not $NativeTF) {
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $smokeScript = Join-Path $repoRoot "qa_test/windows_cli_smoke.ps1"
    $results += Step -Name "Run Windows smoke tests" -Body {
      & $shell -ExecutionPolicy Bypass -File $smokeScript -RepoRoot $repoRoot -NonInteractive -ProbeCuda -InstallTensorflow
    }
  }
}

$cliScript = Join-Path $repoRoot "scripts/plm_cli.py"
$results += Step -Name "Install TensorFlow GPU" -Body { & $python $cliScript --install-tf-gpu }

$results += Step -Name "Native CUDA/TensorFlow detect" -Body {
  & $python $detectScript | Tee-Object -FilePath (Join-Path $debugDir "native_detect.json") | Out-Null
}

if (-not $ContainerPLM) {
  if (-not $NativeTF) {
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $smokeScript = Join-Path $repoRoot "qa_test/windows_cli_smoke.ps1"
    $results += Step -Name "Run Windows smoke tests" -Body {
      & $shell -ExecutionPolicy Bypass -File $smokeScript -RepoRoot $repoRoot -NonInteractive -ProbeCuda -InstallTensorflow
    }
  }
if ($results -notcontains $false) {
    $nativeDetect = $null
    if (Test-Path (Join-Path $debugDir "native_detect.json")) {
      try { $nativeDetect = Get-Content (Join-Path $debugDir "native_detect.json") | ConvertFrom-Json } catch {}
    }
    if ($NativeOnly -and $nativeDetect) {
      $tf = $nativeDetect.tensorflow
      $nvidia = $nativeDetect.nvidia_smi
      $isWindows = $nativeDetect.platform -like "*Windows*"
      if ($isWindows) {
        # On Windows, TF GPU is not supported, so accept if TF present and NVIDIA GPU detected
        if (-not $tf.present -or -not $nvidia.available) {
          Write-Host "Native TensorFlow or NVIDIA GPU not available" -ForegroundColor Red
          $nativeOk = $false
        } else {
          $nativeOk = $true
        }
      } else {
        if (-not $tf.built_with_cuda -or -not $tf.gpus -or $tf.gpus.Count -eq 0) {
          Write-Host "Native GPU/CUDA/TensorFlow not available" -ForegroundColor Red
          $nativeOk = $false
        } else {
          $nativeOk = $true
        }
      }
    } else {
      $nativeOk = $true
    }
  }
}

$containerStep = {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "docker not available" }
  $img = "tensorflow/tensorflow:2.16.1-gpu"
  Write-Host "Pulling $img for GPU smoke..." -ForegroundColor Yellow
  docker pull $img | Out-Null
  $cmd = "import tensorflow as tf; print({'ver':tf.__version__,'built_with_cuda':tf.test.is_built_with_cuda(),'gpus':[d.name for d in tf.config.list_physical_devices('GPU')]})"
  $cOut = docker run --rm --gpus all $img python -c $cmd
  $cOut | Tee-Object -FilePath (Join-Path $debugDir "container_detect.json")
}

$results += Step -Name "Container CUDA/TensorFlow smoke" -Body $containerStep
if ($results[-1]) { $containerOk = $true }

if ($ContainerPLM) {
  $containerPlmStep = {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "docker not available" }
    $img = "python:3.12-slim"
    $cmd = "cd /workspace && python scripts/plm_cli.py --env"
    $cOut = docker run --rm -v `"${repoRoot}:/workspace`" $img bash -c $cmd
    $cOut | Tee-Object -FilePath (Join-Path $debugDir "container_plm_smoke.log")
  }
  $results += Step -Name "Container PLM smoke" -Body $containerPlmStep
  if ($results[-1]) { $containerPlmOk = $true }
}

$allOk = if ($NativeOnly) { $nativeOk }
         elseif ($ContainerOnly) { $containerOk }
         elseif ($NativeTF -and $ContainerPLM) { $nativeOk -and $containerOk -and $containerPlmOk }
         elseif ($NativeTF) { $nativeOk -and $containerOk }
         elseif ($ContainerPLM) { $containerOk -and $containerPlmOk }
         else { $containerOk -or ($PreferContainer -eq $false -and $nativeOk) }
if ($allOk) {
  Write-Host "Automation complete. All steps passed." -ForegroundColor Green
  exit 0
}

Write-Host "Automation finished with failures." -ForegroundColor Red
exit 1
