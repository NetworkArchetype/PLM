Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:PlmAuthCache = $null
$script:PlmAuthHash = $null
$sessionDir = Join-Path $env:TEMP "plm_session"
if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
$sessionFile = Join-Path $sessionDir "auth.dat"
$hashFile = Join-Path $sessionDir "auth.sha256"

function Get-Sha256String([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return $null }
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
  } finally {
    $sha.Dispose()
  }
}

function Get-PlainTextFromSecure([SecureString]$secure) {
  if (-not $secure) { return $null }
  return ([System.Net.NetworkCredential]::new("", $secure)).Password
}

function Read-TokenFromFile {
  if (-not (Test-Path $sessionFile)) { return $null }
  try {
    $secure = Get-Content $sessionFile -Raw | ConvertTo-SecureString
    $plain = Get-PlainTextFromSecure $secure
    if ($plain) {
      $script:PlmAuthHash = Get-Sha256String $plain
      return $plain
    }
  } catch { }
  return $null
}

function Write-TokenToFile([string]$token) {
  try {
    $secure = ConvertTo-SecureString $token -AsPlainText -Force
    $enc = $secure | ConvertFrom-SecureString
    Set-Content -Path $sessionFile -Value $enc -Force
    $hash = Get-Sha256String $token
    if ($hash) { Set-Content -Path $hashFile -Value $hash -Force; $script:PlmAuthHash = $hash }
  } catch { }
}

function Get-TrimmedEnv([string]$name) {
  try {
    $val = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($val)) { return $null }
    return $val.Trim()
  } catch {
    return $null
  }
}

function Read-TokenFromPath([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $null }
  if (-not (Test-Path $path)) { return $null }
  try {
    $txt = (Get-Content $path -Raw).Trim()
    if ($txt) { return $txt }
  } catch { }
  return $null
}

function Resolve-AuthSource {
  $src = (Get-TrimmedEnv "PLM_AUTH_SOURCE")
  if (-not $src) { return "auto" }
  $s = $src.ToLower()
  if ($s -in @("auto","plm","github")) { return $s }
  return "auto"
}

function Get-TokenFromConfiguredSources([string]$source) {
  # source=plm: PLM_AUTH_TOKEN / PLM_AUTH_TOKEN_FILE
  # source=github: GITHUB_TOKEN|GH_TOKEN / GITHUB_TOKEN_FILE|GH_TOKEN_FILE
  # source=auto: prefer PLM, fallback to GitHub

  $token = $null

  if ($source -ieq "plm" -or $source -ieq "auto") {
    $token = Get-TrimmedEnv "PLM_AUTH_TOKEN"
    if ($token) { return $token }
    $token = Read-TokenFromPath (Get-TrimmedEnv "PLM_AUTH_TOKEN_FILE")
    if ($token) { return $token }
  }

  if ($source -ieq "github" -or $source -ieq "auto") {
    $token = Get-TrimmedEnv "GITHUB_TOKEN"
    if (-not $token) { $token = Get-TrimmedEnv "GH_TOKEN" }
    if ($token) { return $token }

    $token = Read-TokenFromPath (Get-TrimmedEnv "GITHUB_TOKEN_FILE")
    if (-not $token) { $token = Read-TokenFromPath (Get-TrimmedEnv "GH_TOKEN_FILE") }
    if ($token) { return $token }
  }

  return $null
}

function New-PlmAuthToken {
  param(
    [int]$Bytes = 32,
    [ValidateSet("base64url","hex")][string]$Format = "base64url",
    [switch]$StoreInSession
  )

  if ($Bytes -lt 16) { throw "Bytes must be >= 16" }

  $buf = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($buf)
  } finally {
    $rng.Dispose()
  }

  $token = $null
  if ($Format -ieq "hex") {
    $token = ($buf | ForEach-Object { $_.ToString("x2") }) -join ""
  } else {
    $b64 = [Convert]::ToBase64String($buf)
    $token = $b64.TrimEnd("=").Replace("+","-").Replace("/","_")
  }

  if ([string]::IsNullOrWhiteSpace($token)) { throw "Failed to generate token" }

  if ($StoreInSession) {
    $script:PlmAuthCache = $token
    $script:PlmAuthHash = Get-Sha256String $token
    Write-TokenToFile $token
  }

  return $token
}

function Prompt-TokenCLI([string]$PromptTitle) {
  $secure = Read-Host "$PromptTitle (input hidden)" -AsSecureString
  return Get-PlainTextFromSecure $secure
}

function Prompt-TokenGUI([string]$PromptTitle) {
  try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue } catch { }
  try { Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue } catch { }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = $PromptTitle
  $form.StartPosition = "CenterScreen"
  $form.Size = New-Object System.Drawing.Size(420,150)

  $label = New-Object System.Windows.Forms.Label
  $label.Text = "Enter authentication token:";
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point(16,16)
  $form.Controls.Add($label)

  $textbox = New-Object System.Windows.Forms.TextBox
  $textbox.UseSystemPasswordChar = $true
  $textbox.Width = 360
  $textbox.Location = New-Object System.Drawing.Point(16,40)
  $form.Controls.Add($textbox)

  $okButton = New-Object System.Windows.Forms.Button
  $okButton.Text = "OK"
  $okButton.Location = New-Object System.Drawing.Point(216,75)
  $okButton.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::OK; $form.Close() })
  $form.Controls.Add($okButton)

  $cancelButton = New-Object System.Windows.Forms.Button
  $cancelButton.Text = "Cancel"
  $cancelButton.Location = New-Object System.Drawing.Point(300,75)
  $cancelButton.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
  $form.Controls.Add($cancelButton)

  if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $textbox.Text
}

function Get-PlmAuthToken {
  param(
    [ValidateSet("CLI","GUI")][string]$Mode = "CLI",
    [string]$PromptTitle = "PLM Authentication",
    [switch]$NonInteractive
  )

  if ($script:PlmAuthCache) { return $script:PlmAuthCache }

  $source = Resolve-AuthSource
  $fromEnv = Get-TokenFromConfiguredSources $source
  if ($fromEnv) {
    $script:PlmAuthCache = $fromEnv
    $script:PlmAuthHash = Get-Sha256String $fromEnv
    return $fromEnv
  }

  $session = Read-TokenFromFile
  if ($session) { $script:PlmAuthCache = $session; return $session }

  if ($NonInteractive) {
    throw "No authentication token found. Set PLM_AUTH_TOKEN/PLM_AUTH_TOKEN_FILE (or set PLM_AUTH_SOURCE=github and provide GITHUB_TOKEN/GH_TOKEN)."
  }

  $token = if ($Mode -ieq "GUI") { Prompt-TokenGUI $PromptTitle } else { Prompt-TokenCLI $PromptTitle }
  if ([string]::IsNullOrWhiteSpace($token)) { throw "Authentication canceled or empty." }

  $script:PlmAuthCache = $token
  Write-TokenToFile $token
  return $token
}

function Get-PlmAuthTokenHash {
  if ($script:PlmAuthHash) { return $script:PlmAuthHash }
  if (-not $script:PlmAuthCache) { return $null }
  $script:PlmAuthHash = Get-Sha256String $script:PlmAuthCache
  return $script:PlmAuthHash
}

function Clear-PlmAuthSession {
  $script:PlmAuthCache = $null
  $script:PlmAuthHash = $null
  if (Test-Path $sessionFile) { Remove-Item $sessionFile -Force -ErrorAction SilentlyContinue }
  if (Test-Path $hashFile) { Remove-Item $hashFile -Force -ErrorAction SilentlyContinue }
}
