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
        throw "winget not found."
    }
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
}

function Winget-Uninstall([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found."
    }
    winget uninstall --id $Id --silent
}

if ($Enable) {
    Write-Host "Enabling CUDA..."
    if (-not (Get-Command nvcc -ErrorAction SilentlyContinue)) {
        Write-Host "Installing NVIDIA CUDA Toolkit..."
        try {
            Winget-Install "Nvidia.CUDA"
            Write-Host "CUDA Toolkit installed."
        } catch {
            Write-Host "Failed to install CUDA: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Host "CUDA Toolkit already installed."
    }
    # Install TensorFlow GPU
    Write-Host "Installing TensorFlow GPU..."
    try {
        & ".\venv\Scripts\python.exe" -m pip install tensorflow[and-cuda]
        Write-Host "TensorFlow GPU installed."
    } catch {
        Write-Host "Failed to install TensorFlow GPU: $($_.Exception.Message)"
    }
    # Create config
    $config = @{ CUDA_Enabled = $true }
    $config | ConvertTo-Json | Set-Content $configPath
    Write-Host "CUDA enabled. Config saved to $configPath"
}

if ($Disable) {
    Write-Host "Disabling CUDA..."
    # Optionally uninstall CUDA
    if (Get-Command nvcc -ErrorAction SilentlyContinue) {
        Write-Host "Uninstalling NVIDIA CUDA Toolkit..."
        try {
            Winget-Uninstall "Nvidia.CUDA"
            Write-Host "CUDA Toolkit uninstalled."
        } catch {
            Write-Host "Failed to uninstall CUDA: $($_.Exception.Message)"
        }
    }
    # Create config
    $config = @{ CUDA_Enabled = $false }
    $config | ConvertTo-Json | Set-Content $configPath
    Write-Host "CUDA disabled. Config saved to $configPath"
}