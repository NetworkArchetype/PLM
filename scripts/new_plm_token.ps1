param(
  [int]$Bytes = 32,
  [ValidateSet("base64url","hex")][string]$Format = "base64url",
  [switch]$StoreInSession,
  [switch]$SetEnv,
  [string]$OutFile,
  [switch]$AllowInRepo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptsDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptsDir
$authHelper = Join-Path $repoRoot "scripts/auth_session.ps1"
if (-not (Test-Path $authHelper)) { throw "Missing auth helper: $authHelper" }
. $authHelper

$token = New-PlmAuthToken -Bytes $Bytes -Format $Format -StoreInSession:$StoreInSession

if ($OutFile) {
  $repoFull = [System.IO.Path]::GetFullPath($repoRoot)
  $outFull = [System.IO.Path]::GetFullPath($OutFile)
  if (-not $AllowInRepo -and $outFull.StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write a token under the repo tree: $outFull. Choose a path outside the repo (or pass -AllowInRepo)."
  }
  $outDir = Split-Path -Parent $outFull
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
  Set-Content -Path $outFull -Value $token -Encoding utf8
}

if ($SetEnv) {
  $env:PLM_AUTH_TOKEN = $token
}

Write-Output $token
