param(
  [switch]$Clear
)

$helper = Join-Path (Split-Path -Parent $PSCommandPath) "auth_session.ps1"
if (-not (Test-Path $helper)) { Write-Error "auth_session.ps1 not found."; exit 1 }
. $helper

if ($Clear) {
  Clear-PlmAuthSession
  Write-Host "Cleared cached session/auth files." -ForegroundColor Yellow
  exit 0
}

try {
  $token = Get-PlmAuthToken -Mode "CLI" -PromptTitle "Test authentication"
  $hash = Get-PlmAuthTokenHash
  Write-Host "Token acquired (length: $($token.Length))" -ForegroundColor Cyan
  Write-Host "SHA256 (for debug only): $hash" -ForegroundColor Gray
} catch {
  Write-Error "Auth failed: $($_.Exception.Message)"
  exit 1
}
