param(
  [string]$RepoUrl = "https://github.com/NetworkArchetype/PLM.git",
  [switch]$IncludeDocker = $false,
  [switch]$IncludeCuda = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git is required to clone sandbox."
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("plm-sandbox-" + [guid]::NewGuid())
Write-Host "[QA] Creating sandbox at $root" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $root | Out-Null

try {
  Write-Host "[QA] Cloning $RepoUrl" -ForegroundColor Yellow
  git clone $RepoUrl $root

  $qaScript = Join-Path $root "qa_test/windows_cli_smoke.ps1"
  if (-not (Test-Path $qaScript)) { throw "qa_test/windows_cli_smoke.ps1 missing in clone" }

  Write-Host "[QA] Running base smoke (IncludeCuda=$IncludeCuda)" -ForegroundColor Yellow
  pwsh -File $qaScript -RepoRoot $root -ProbeCuda:$IncludeCuda -NonInteractive

  if ($IncludeDocker) {
    Write-Host "[QA] Docker enablement pass" -ForegroundColor Yellow
    $py = Join-Path $root "venv/Scripts/python.exe"
    if (-not (Test-Path $py)) { $py = "python" }
    Push-Location $root
    try {
      & $py scripts/plm_cli.py --ensure-docker --log-level debug
    } catch {
      Write-Warning "Docker ensure/start failed: $($_.Exception.Message)"
    } finally {
      Pop-Location
    }
  }

  Write-Host "[QA] Sandbox run complete" -ForegroundColor Green
} finally {
  Write-Host "[QA] Sandbox path retained: $root" -ForegroundColor Cyan
}
