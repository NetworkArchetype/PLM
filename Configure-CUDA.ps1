# Configure-CUDA.ps1
# Script to enable or disable CUDA for PLM environment.
# Usage: .\Configure-CUDA.ps1 -Enable
#        .\Configure-CUDA.ps1 -Disable

param(
    [switch]$Enable,
    [switch]$Disable
)

if (-not $Enable -and -not $Disable) {
    Write-Host "Usage: .\Configure-CUDA.ps1 -Enable or -Disable"
    exit 1
}

$configPath = "$PSScriptRoot\cuda_config.json"

function Winget-Install([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from Microsoft Store."
    }
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
}

function Winget-Uninstall([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from Microsoft Store."
    }
    winget uninstall --id $Id --silent | Out-Host
}

function Get-PythonExe {
    $candidates = @(
        (Join-Path $PSScriptRoot ".venv\\Scripts\\python.exe"),
        (Join-Path $PSScriptRoot "venv\\Scripts\\python.exe")
    )
    foreach ($repoPy in $candidates) {
        if (Test-Path $repoPy) { return $repoPy }
    }
    if (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    return $null
}

function Install-TensorFlowGPU {
    $py = Get-PythonExe
    if (-not $py) { Write-Host "Python not found; install Python first."; return }
    Write-Host "Installing TensorFlow GPU with CUDA extras..."
    & $py -m pip install --upgrade pip | Out-Host
    & $py -m pip install tensorflow[and-cuda] | Out-Host
    Write-Host "TensorFlow GPU install attempt finished."
}

if ($Enable) {
    Write-Host "Enabling CUDA..."
    if (-not (Get-Command nvcc -ErrorAction SilentlyContinue)) {
        Write-Host "Installing NVIDIA CUDA Toolkit via winget..."
        try {
            Winget-Install "Nvidia.CUDA"
            Write-Host "CUDA Toolkit install attempted. Reboot/logoff may be required for PATH."
        } catch {
            Write-Host "Failed to install CUDA: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Host "CUDA Toolkit already installed (nvcc found)."
    }

    Install-TensorFlowGPU

    $config = @{ CUDA_Enabled = $true }
    $config | ConvertTo-Json | Set-Content $configPath
    Write-Host "CUDA enabled. Config saved to $configPath"
}

if ($Disable) {
    Write-Host "Disabling CUDA..."
    if (Get-Command nvcc -ErrorAction SilentlyContinue) {
        Write-Host "Uninstalling NVIDIA CUDA Toolkit via winget..."
        try {
            Winget-Uninstall "Nvidia.CUDA"
            Write-Host "CUDA Toolkit uninstall attempted."
        } catch {
            Write-Host "Failed to uninstall CUDA: $($_.Exception.Message)"
        }
    }

    $config = @{ CUDA_Enabled = $false }
    $config | ConvertTo-Json | Set-Content $configPath
    Write-Host "CUDA disabled. Config saved to $configPath"
}