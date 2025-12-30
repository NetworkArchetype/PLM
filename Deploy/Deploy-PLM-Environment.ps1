<# Deploy-PLM-Environment.ps1
   Windows 11 + VS Code + WSL2 + Docker Desktop + Python toolchain for PLM/Cirq
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
      "-NoProfile","-ExecutionPolicy","Bypass","-File",$PSCommandPath
    ) | Out-Null
    exit 0
  }
}

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store, then rerun."
  }
}

function Winget-Install([string]$Id) {
  Write-Host "Installing: $Id" -ForegroundColor Cyan
  winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
}

function Find-CodeCmd {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  if (Get-Command code -ErrorAction SilentlyContinue) { return (Get-Command code).Source }
  return $null
}

function Install-VSCodeExtensions([string]$codeCmd) {
  $exts = @(
    "ms-python.python",
    "ms-toolsai.jupyter",
    "ms-vscode-remote.remote-wsl",
    "ms-azuretools.vscode-docker",
    "ms-vscode.powershell"
  )
  foreach ($e in $exts) {
    Write-Host "VS Code ext: $e" -ForegroundColor Cyan
    & $codeCmd --install-extension $e --force | Out-Host
  }
}

Ensure-Admin
Ensure-Winget

Write-Host "== Core tools ==" -ForegroundColor Green
Winget-Install "Git.Git"
Winget-Install "Python.Python.3.12"
Winget-Install "Microsoft.VisualStudioCode"
Winget-Install "Microsoft.WindowsTerminal"

Write-Host "== Enable WSL2 ==" -ForegroundColor Green
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
wsl.exe --set-default-version 2 | Out-Host
try { wsl.exe --install -d Ubuntu | Out-Host } catch { Write-Host "Ubuntu may already be installed or needs reboot." -ForegroundColor Yellow }

Write-Host "== Docker Desktop (docker.io via Docker Desktop) ==" -ForegroundColor Green
Winget-Install "Docker.DockerDesktop"

Write-Host ""
Write-Host "NOTE:" -ForegroundColor Yellow
Write-Host "  1) If you just enabled WSL features, reboot may be required." -ForegroundColor Yellow
Write-Host "  2) Start Docker Desktop once and enable WSL2 engine + Ubuntu integration." -ForegroundColor Yellow

Write-Host "== VS Code extensions ==" -ForegroundColor Green
$codeCmd = Find-CodeCmd
if ($codeCmd) { Install-VSCodeExtensions $codeCmd }
else { Write-Host "VS Code CLI not found yet. Launch VS Code once, then rerun." -ForegroundColor Yellow }

Write-Host "Done: environment deployed." -ForegroundColor Green
# End of Deploy-PLM-Environment.ps1
