[CmdletBinding()]
param(
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$hooksPath = ".githooks"

Write-Host "Configuring git hooksPath to $hooksPath" -ForegroundColor Cyan

Push-Location (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
try {
  git rev-parse --is-inside-work-tree | Out-Null

$existing = (git config --get core.hooksPath)
if ($existing -and -not $Force) {
  Write-Host "core.hooksPath already set to: $existing" -ForegroundColor Yellow
  Write-Host "Use -Force to override." -ForegroundColor Yellow
  exit 0
}

  git config core.hooksPath $hooksPath

  Write-Host "Done. Current core.hooksPath: $(git config --get core.hooksPath)" -ForegroundColor Green
  Write-Host "Note: On Windows, hook executability is handled by git; ensure the hook files have valid shebangs." -ForegroundColor Gray
} finally {
  Pop-Location
}
