param(
  [switch]$WithGPU
)

$ErrorActionPreference = "Stop"

function Run-Step($name, [ScriptBlock]$body) {
  Write-Host "[STEP] $name" -ForegroundColor Cyan
  try {
    & $body
    Write-Host "[OK] $name" -ForegroundColor Green
    return $true
  } catch {
    Write-Host "[FAIL] $name :: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

$results = @()

$results += Run-Step "Create venv" { python -m venv venv }
$results += Run-Step "Upgrade pip" { .\venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel }
$results += Run-Step "Install PLM (editable)" { .\venv\Scripts\python.exe -m pip install -e .\Code_core_3\plm-formalized }

if ($WithGPU) {
  $results += Run-Step "Install qsimcirq (GPU)" { .\venv\Scripts\python.exe -m pip install qsimcirq }
}

$results += Run-Step "Run smoke test" { .\venv\Scripts\python.exe test_installation.py }

$allOk = ($results -notcontains $false)
if ($allOk) {
  Write-Host "All local CI steps passed." -ForegroundColor Green
  exit 0
} else {
  Write-Host "Some steps failed. See output above." -ForegroundColor Red
  exit 1
}
