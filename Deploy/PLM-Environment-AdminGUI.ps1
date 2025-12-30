<#  PLM-Environment-AdminGUI.ps1
    Admin GUI to detect + manage the environment deployed by Deploy-PLM-Environment.ps1.
    WinForms GUI (built-in), runs elevated, supports Native/WSL/Docker/Hyper-V modes.
#>

[CmdletBinding()]
param(
  [string]$DeployScriptPath = ""   # optional: full path to Deploy-PLM-Environment.ps1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------
# Elevation
# -----------------------------
function Ensure-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-File",$PSCommandPath)
    if ($DeployScriptPath) { $args += @("-DeployScriptPath", $DeployScriptPath) }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args | Out-Null
    exit 0
  }
}
Ensure-Admin

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------
# Utilities
# -----------------------------
$script:txtLog = $null
function Log([string]$msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  if ($script:txtLog) {
    $script:txtLog.AppendText("[$ts] $msg`r`n")
    $script:txtLog.SelectionStart = $script:txtLog.TextLength
    $script:txtLog.ScrollToCaret()
  } else {
    Write-Host "[$ts] $msg"
  }
}

function Try-Run([scriptblock]$sb, [string]$okMsg, [string]$failMsg) {
  try { & $sb; Log $okMsg; return $true }
  catch { Log ($failMsg + " :: " + $_.Exception.Message); return $false }
}

function Exists-Cmd([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Winget-Ok { Exists-Cmd "winget" }

function Winget-Install([string]$Id) {
  if (-not (Winget-Ok)) { throw "winget not found (install App Installer from Microsoft Store)." }
  winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
}

function Winget-Upgrade([string]$Id) {
  if (-not (Winget-Ok)) { throw "winget not found (install App Installer from Microsoft Store)." }
  winget upgrade --id $Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
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
  foreach ($e in $exts) { & $codeCmd --install-extension $e --force | Out-Host }
}

function Open-Terminal([string]$kind) {
  switch ($kind) {
    "ps-admin" { Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile" | Out-Null; Log "Opened Admin PowerShell." }
    "cmd-admin"{ Start-Process cmd.exe       -Verb RunAs | Out-Null; Log "Opened Admin CMD." }
    "wt"       { Start-Process wt.exe | Out-Null; Log "Opened Windows Terminal." }
    "wsl"      { Start-Process wsl.exe -ArgumentList "-d Ubuntu" | Out-Null; Log "Opened WSL Ubuntu." }
    default    { Log "Unknown terminal kind: $kind" }
  }
}

function Open-DockerBash([string]$image) {
  if (-not (Exists-Cmd "docker")) { Log "Docker not found."; return }
  if (-not $image) { $image = "networkarchetype-plm:latest" }
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit","-Command","docker run --rm -it $image bash" | Out-Null
  Log "Opened Docker bash: $image"
}

# -----------------------------
# Detection
# -----------------------------
function Detect-WSLFeatureEnabled {
  $res = dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux 2>$null
  return ($res -match "State : Enabled")
}
function Detect-VMPFeatureEnabled {
  $res = dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform 2>$null
  return ($res -match "State : Enabled")
}
function Detect-HyperVEnabled {
  # Hyper-V optional feature (not available on Home unless enabled via other means)
  $res = dism.exe /online /get-featureinfo /featurename:Microsoft-Hyper-V-All 2>$null
  if ($LASTEXITCODE -ne 0) { return $false }
  return ($res -match "State : Enabled")
}
function Detect-UbuntuInstalled {
  if (-not (Exists-Cmd "wsl")) { return $false }
  try {
    $list = wsl.exe -l -q 2>$null
    return ($list -match "(?m)^Ubuntu$")
  } catch { return $false }
}
function Detect-DockerDesktop {
  # Quick check: docker cli + docker server reachable
  if (-not (Exists-Cmd "docker")) { return $false }
  try {
    docker version --format "{{.Server.Version}}" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

function Detect-Environment {
  $codeCmd = Find-CodeCmd
  $state = [ordered]@{
    Winget         = Winget-Ok
    Git            = Exists-Cmd "git"
    Python         = Exists-Cmd "python"
    VSCode         = [bool]$codeCmd
    VSCodeCmd      = $codeCmd
    WindowsTerminal= Exists-Cmd "wt"
    WSLFeature     = Detect-WSLFeatureEnabled
    VMPFeature     = Detect-VMPFeatureEnabled
    WSL            = Exists-Cmd "wsl"
    Ubuntu         = Detect-UbuntuInstalled
    Docker         = Detect-DockerDesktop
    HyperV         = Detect-HyperVEnabled
    NvidiaSMI      = Exists-Cmd "nvidia-smi"
  }
  return $state
}

function Status-Color([bool]$ok) {
  if ($ok) { return [System.Drawing.Color]::FromArgb(0,140,0) }
  return [System.Drawing.Color]::FromArgb(180,0,0)
}

# These label vars are created later (after GUI instantiation)
$script:lblWingetValue = $null
$script:lblGitValue = $null
$script:lblPythonValue = $null
$script:lblVSCodeValue = $null
$script:lblWTValue = $null
$script:lblWSLFeatValue = $null
$script:lblUbuntuValue = $null
$script:lblDockerValue = $null
$script:lblHyperVValue = $null
$script:lblNvidiaValue = $null

function Render-Status($s) {
  $script:lblWingetValue.ForeColor = Status-Color $s.Winget
  $script:lblWingetValue.Text      = $(if ($s.Winget){"OK"} else {"Missing"})

  $script:lblGitValue.ForeColor = Status-Color $s.Git
  $script:lblGitValue.Text      = $(if ($s.Git){"OK"} else {"Missing"})

  $script:lblPythonValue.ForeColor = Status-Color $s.Python
  $script:lblPythonValue.Text      = $(if ($s.Python){"OK"} else {"Missing"})

  $script:lblVSCodeValue.ForeColor = Status-Color $s.VSCode
  $script:lblVSCodeValue.Text      = $(if ($s.VSCode){"OK"} else {"Missing"})

  $script:lblWTValue.ForeColor = Status-Color $s.WindowsTerminal
  $script:lblWTValue.Text      = $(if ($s.WindowsTerminal){"OK"} else {"Missing"})

  $script:lblWSLFeatValue.ForeColor = Status-Color ($s.WSLFeature -and $s.VMPFeature)
  $script:lblWSLFeatValue.Text      = $(if ($s.WSLFeature -and $s.VMPFeature){"Enabled"} else {"Disabled"})

  $script:lblUbuntuValue.ForeColor = Status-Color $s.Ubuntu
  $script:lblUbuntuValue.Text      = $(if ($s.Ubuntu){"Installed"} else {"Missing"})

  $script:lblDockerValue.ForeColor = Status-Color $s.Docker
  $script:lblDockerValue.Text      = $(if ($s.Docker){"OK"} else {"Missing/Stopped"})

  $script:lblHyperVValue.ForeColor = Status-Color $s.HyperV
  $script:lblHyperVValue.Text      = $(if ($s.HyperV){"Enabled"} else {"Disabled/Unavailable"})

  $script:lblNvidiaValue.ForeColor = Status-Color $s.NvidiaSMI
  $script:lblNvidiaValue.Text      = $(if ($s.NvidiaSMI){"OK"} else {"Not found"})
}

# -----------------------------
# Actions: Install/Update/Repair
# -----------------------------
function Do-InstallOrRepair {
  $s = Detect-Environment
  Render-Status $s
  Log "Starting Install/Repair..."

  if (-not $s.Winget) { Log "winget missing. Install 'App Installer' from Microsoft Store."; return }

  Try-Run { Winget-Install "Git.Git" } "Git install OK" "Git install failed" | Out-Null
  Try-Run { Winget-Install "Python.Python.3.12" } "Python install OK" "Python install failed" | Out-Null
  Try-Run { Winget-Install "Microsoft.VisualStudioCode" } "VS Code install OK" "VS Code install failed" | Out-Null
  Try-Run { Winget-Install "Microsoft.WindowsTerminal" } "Windows Terminal install OK" "Windows Terminal install failed" | Out-Null
  Try-Run { Winget-Install "Docker.DockerDesktop" } "Docker Desktop install OK" "Docker Desktop install failed" | Out-Null

  Log "Enabling WSL2 features..."
  Try-Run { dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null } "WSL feature enable OK" "WSL feature enable failed" | Out-Null
  Try-Run { dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null } "VMP enable OK" "VMP enable failed" | Out-Null

  if (Exists-Cmd "wsl") {
    Try-Run { wsl.exe --set-default-version 2 | Out-Host } "WSL default version set to 2" "WSL set-default-version failed" | Out-Null
    Try-Run { wsl.exe --install -d Ubuntu | Out-Host } "Ubuntu install triggered" "Ubuntu install may already exist / needs reboot" | Out-Null
  }

  $codeCmd = Find-CodeCmd
  if ($codeCmd) {
    Log "Installing VS Code extensions..."
    Try-Run { Install-VSCodeExtensions $codeCmd } "VS Code extensions OK" "VS Code extensions failed" | Out-Null
  } else {
    Log "VS Code CLI not detected yet (launch VS Code once, then run Extensions install)."
  }

  Log "Install/Repair finished. You may need to reboot if WSL features were just enabled."
  Render-Status (Detect-Environment)
}

function Do-Update {
  $s = Detect-Environment
  Render-Status $s
  if (-not $s.Winget) { Log "winget missing; cannot update."; return }

  Log "Updating packages (winget upgrade)..."
  foreach ($id in @("Git.Git","Python.Python.3.12","Microsoft.VisualStudioCode","Microsoft.WindowsTerminal","Docker.DockerDesktop")) {
    Try-Run { Winget-Upgrade $id } "Upgraded: $id" "Upgrade failed: $id" | Out-Null
  }

  $codeCmd = Find-CodeCmd
  if ($codeCmd) {
    Log "Re-applying VS Code extensions (idempotent)..."
    Try-Run { Install-VSCodeExtensions $codeCmd } "VS Code extensions OK" "VS Code extensions failed" | Out-Null
  }

  Render-Status (Detect-Environment)
  Log "Update finished."
}

function Do-RunDeployScript {
  if (-not $DeployScriptPath -or -not (Test-Path $DeployScriptPath)) {
    [System.Windows.Forms.MessageBox]::Show(
      "Deploy script not set or not found. Use 'Select Deploy Script' first.",
      "Missing Deploy Script",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    return
  }
  Log "Running deploy script: $DeployScriptPath"
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$DeployScriptPath | Out-Null
}

# -----------------------------
# Hyper-V sandbox helpers
# -----------------------------
function Do-OpenHyperVManager {
  # Hyper-V Manager (virtmgmt.msc) if installed
  if (Test-Path "$env:WINDIR\System32\virtmgmt.msc") {
    Start-Process mmc.exe -Verb RunAs -ArgumentList "$env:WINDIR\System32\virtmgmt.msc" | Out-Null
    Log "Opened Hyper-V Manager."
  } else {
    Log "Hyper-V Manager not found (Hyper-V may be unavailable on this edition)."
  }
}

function Do-CreateHyperVSandboxNote {
  $msg = @"
Hyper-V Sandbox Mode (GUI):
- Use Hyper-V Manager to create a VM (Windows or Ubuntu).
- Mount an ISO and install.
- Then run Deploy-PLM-Environment.ps1 inside the VM.

This GUI can open Hyper-V Manager and provide the deployed scripts folder path.
"@
  [System.Windows.Forms.MessageBox]::Show($msg, "Hyper-V Sandbox Notes",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

# -----------------------------
# GUI Layout
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "PLM Environment Admin GUI (Native / WSL / Docker / Hyper-V)"
$form.Size = New-Object System.Drawing.Size(1100, 740)
$form.StartPosition = "CenterScreen"

$font = New-Object System.Drawing.Font("Segoe UI", 10)

# Header panel
$pTop = New-Object System.Windows.Forms.Panel
$pTop.Dock = "Top"
$pTop.Height = 250
$form.Controls.Add($pTop)

# Status group
$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = "Environment Detection"
$grpStatus.Font = $font
$grpStatus.Location = New-Object System.Drawing.Point(12, 10)
$grpStatus.Size = New-Object System.Drawing.Size(520, 230)
$pTop.Controls.Add($grpStatus)

function Add-StatusRow($parent, $label, $y, [ref]$valueLabel) {
  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = $label
  $lbl.Location = New-Object System.Drawing.Point(16, $y)
  $lbl.Size = New-Object System.Drawing.Size(210, 22)
  $lbl.Font = $font
  $parent.Controls.Add($lbl)

  $val = New-Object System.Windows.Forms.Label
  $val.Text = "-"
  $val.Location = New-Object System.Drawing.Point(240, $y)
  $val.Size = New-Object System.Drawing.Size(240, 22)
  $val.Font = $font
  $parent.Controls.Add($val)

  $valueLabel.Value = $val
}

# IMPORTANT: keep each call on ONE LINE (your original parse error)
Add-StatusRow $grpStatus "winget"               30 ([ref]$script:lblWingetValue)
Add-StatusRow $grpStatus "Git"                  55 ([ref]$script:lblGitValue)
Add-StatusRow $grpStatus "Python"               80 ([ref]$script:lblPythonValue)
Add-StatusRow $grpStatus "VS Code (any version)" 105 ([ref]$script:lblVSCodeValue)
Add-StatusRow $grpStatus "Windows Terminal"     130 ([ref]$script:lblWTValue)
Add-StatusRow $grpStatus "WSL2 Features"        155 ([ref]$script:lblWSLFeatValue)
Add-StatusRow $grpStatus "Ubuntu (WSL distro)"  180 ([ref]$script:lblUbuntuValue)
Add-StatusRow $grpStatus "Docker Desktop"       205 ([ref]$script:lblDockerValue)

# Right side group: Modes + actions
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = "Actions & Modes"
$grpActions.Font = $font
$grpActions.Location = New-Object System.Drawing.Point(548, 10)
$grpActions.Size = New-Object System.Drawing.Size(520, 230)
$pTop.Controls.Add($grpActions)

# Deploy script selector
$lblDeploy = New-Object System.Windows.Forms.Label
$lblDeploy.Text = "Deploy script (optional):"
$lblDeploy.Location = New-Object System.Drawing.Point(16, 30)
$lblDeploy.Size = New-Object System.Drawing.Size(180, 22)
$lblDeploy.Font = $font
$grpActions.Controls.Add($lblDeploy)

$txtDeploy = New-Object System.Windows.Forms.TextBox
$txtDeploy.Location = New-Object System.Drawing.Point(200, 28)
$txtDeploy.Size = New-Object System.Drawing.Size(240, 26)
$txtDeploy.Font = $font
$txtDeploy.Text = $DeployScriptPath
$grpActions.Controls.Add($txtDeploy)

$btnPickDeploy = New-Object System.Windows.Forms.Button
$btnPickDeploy.Text = "Select"
$btnPickDeploy.Location = New-Object System.Drawing.Point(450, 26)
$btnPickDeploy.Size = New-Object System.Drawing.Size(55, 30)
$btnPickDeploy.Font = $font
$grpActions.Controls.Add($btnPickDeploy)

# Buttons: Detect/Install/Update/Run deploy
$btnDetect = New-Object System.Windows.Forms.Button
$btnDetect.Text = "Detect"
$btnDetect.Location = New-Object System.Drawing.Point(16, 70)
$btnDetect.Size = New-Object System.Drawing.Size(110, 34)
$btnDetect.Font = $font
$grpActions.Controls.Add($btnDetect)

$btnInstallRepair = New-Object System.Windows.Forms.Button
$btnInstallRepair.Text = "Install / Repair"
$btnInstallRepair.Location = New-Object System.Drawing.Point(136, 70)
$btnInstallRepair.Size = New-Object System.Drawing.Size(140, 34)
$btnInstallRepair.Font = $font
$grpActions.Controls.Add($btnInstallRepair)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "Update"
$btnUpdate.Location = New-Object System.Drawing.Point(286, 70)
$btnUpdate.Size = New-Object System.Drawing.Size(90, 34)
$btnUpdate.Font = $font
$grpActions.Controls.Add($btnUpdate)

$btnRunDeploy = New-Object System.Windows.Forms.Button
$btnRunDeploy.Text = "Run Deploy Script"
$btnRunDeploy.Location = New-Object System.Drawing.Point(386, 70)
$btnRunDeploy.Size = New-Object System.Drawing.Size(120, 34)
$btnRunDeploy.Font = $font
$grpActions.Controls.Add($btnRunDeploy)

# Mode selector
$lblMode = New-Object System.Windows.Forms.Label
$lblMode.Text = "Run Mode:"
$lblMode.Location = New-Object System.Drawing.Point(16, 120)
$lblMode.Size = New-Object System.Drawing.Size(90, 22)
$lblMode.Font = $font
$grpActions.Controls.Add($lblMode)

$cmbMode = New-Object System.Windows.Forms.ComboBox
$cmbMode.Location = New-Object System.Drawing.Point(110, 118)
$cmbMode.Size = New-Object System.Drawing.Size(180, 28)
$cmbMode.Font = $font
$cmbMode.DropDownStyle = "DropDownList"
[void]$cmbMode.Items.Add("Native (Windows)")
[void]$cmbMode.Items.Add("WSL (Ubuntu)")
[void]$cmbMode.Items.Add("Docker Sandbox")
[void]$cmbMode.Items.Add("Hyper-V Sandbox")
$cmbMode.SelectedIndex = 0
$grpActions.Controls.Add($cmbMode)

# Terminal buttons
$btnPS = New-Object System.Windows.Forms.Button
$btnPS.Text = "Admin PowerShell"
$btnPS.Location = New-Object System.Drawing.Point(16, 160)
$btnPS.Size = New-Object System.Drawing.Size(140, 34)
$btnPS.Font = $font
$grpActions.Controls.Add($btnPS)

$btnWSL = New-Object System.Windows.Forms.Button
$btnWSL.Text = "WSL Bash"
$btnWSL.Location = New-Object System.Drawing.Point(166, 160)
$btnWSL.Size = New-Object System.Drawing.Size(100, 34)
$btnWSL.Font = $font
$grpActions.Controls.Add($btnWSL)

$btnWT = New-Object System.Windows.Forms.Button
$btnWT.Text = "Windows Terminal"
$btnWT.Location = New-Object System.Drawing.Point(276, 160)
$btnWT.Size = New-Object System.Drawing.Size(140, 34)
$btnWT.Font = $font
$grpActions.Controls.Add($btnWT)

$btnDockerBash = New-Object System.Windows.Forms.Button
$btnDockerBash.Text = "Docker Bash"
$btnDockerBash.Location = New-Object System.Drawing.Point(426, 160)
$btnDockerBash.Size = New-Object System.Drawing.Size(80, 34)
$btnDockerBash.Font = $font
$grpActions.Controls.Add($btnDockerBash)

# Hyper-V controls
$lblHyperV = New-Object System.Windows.Forms.Label
$lblHyperV.Text = "Hyper-V:"
$lblHyperV.Location = New-Object System.Drawing.Point(306, 120)
$lblHyperV.Size = New-Object System.Drawing.Size(70, 22)
$lblHyperV.Font = $font
$grpActions.Controls.Add($lblHyperV)

$script:lblHyperVValue = New-Object System.Windows.Forms.Label
$script:lblHyperVValue.Text = "-"
$script:lblHyperVValue.Location = New-Object System.Drawing.Point(380, 120)
$script:lblHyperVValue.Size = New-Object System.Drawing.Size(130, 22)
$script:lblHyperVValue.Font = $font
$grpActions.Controls.Add($script:lblHyperVValue)

$btnHyperV = New-Object System.Windows.Forms.Button
$btnHyperV.Text = "Open Hyper-V"
$btnHyperV.Location = New-Object System.Drawing.Point(306, 196)
$btnHyperV.Size = New-Object System.Drawing.Size(120, 30)
$btnHyperV.Font = $font
$grpActions.Controls.Add($btnHyperV)

$btnHyperVNote = New-Object System.Windows.Forms.Button
$btnHyperVNote.Text = "Sandbox Help"
$btnHyperVNote.Location = New-Object System.Drawing.Point(436, 196)
$btnHyperVNote.Size = New-Object System.Drawing.Size(70, 30)
$btnHyperVNote.Font = $font
$grpActions.Controls.Add($btnHyperVNote)

# Bottom log
$script:txtLog = New-Object System.Windows.Forms.TextBox
$script:txtLog.Multiline = $true
$script:txtLog.ReadOnly = $true
$script:txtLog.ScrollBars = "Vertical"
$script:txtLog.Dock = "Fill"
$script:txtLog.Font = New-Object System.Drawing.Font("Consolas", 10)
$form.Controls.Add($script:txtLog)

# NVIDIA label in status group (added after log init)
$lblNvidiaTitle = New-Object System.Windows.Forms.Label
$lblNvidiaTitle.Text = "nvidia-smi (Windows)"
$lblNvidiaTitle.Location = New-Object System.Drawing.Point(16, 230)
$lblNvidiaTitle.Size = New-Object System.Drawing.Size(210, 22)
$lblNvidiaTitle.Font = $font
$grpStatus.Controls.Add($lblNvidiaTitle)

$script:lblNvidiaValue = New-Object System.Windows.Forms.Label
$script:lblNvidiaValue.Text = "-"
$script:lblNvidiaValue.Location = New-Object System.Drawing.Point(240, 230)
$script:lblNvidiaValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblNvidiaValue.Font = $font
$grpStatus.Controls.Add($script:lblNvidiaValue)

# Adjust grpStatus height slightly
$grpStatus.Height = 240

# -----------------------------
# GUI Events
# -----------------------------
$btnPickDeploy.Add_Click({
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
  $dlg.Title = "Select Deploy-PLM-Environment.ps1"
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $DeployScriptPath = $dlg.FileName
    $txtDeploy.Text = $DeployScriptPath
    Log "Deploy script set: $DeployScriptPath"
  }
})

$btnDetect.Add_Click({
  Log "Detecting environment..."
  $s = Detect-Environment
  Render-Status $s
  Log ("Detected: " + (($s.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "))
})

$btnInstallRepair.Add_Click({ Do-InstallOrRepair })
$btnUpdate.Add_Click({ Do-Update })

$btnRunDeploy.Add_Click({
  $DeployScriptPath = $txtDeploy.Text
  Do-RunDeployScript
})

$btnPS.Add_Click({ Open-Terminal "ps-admin" })
$btnWSL.Add_Click({ Open-Terminal "wsl" })
$btnWT.Add_Click({ Open-Terminal "wt" })

$btnDockerBash.Add_Click({
  # Choose image based on mode or default
  $img = "networkarchetype-plm:latest"
  Open-DockerBash $img
})

$btnHyperV.Add_Click({ Do-OpenHyperVManager })
$btnHyperVNote.Add_Click({ Do-CreateHyperVSandboxNote })

# Mode change logs
$cmbMode.Add_SelectedIndexChanged({
  $mode = $cmbMode.SelectedItem.ToString()
  Log "Selected mode: $mode"
  switch ($mode) {
    "Native (Windows)"  { }
    "WSL (Ubuntu)"      { }
    "Docker Sandbox"    { }
    "Hyper-V Sandbox"   { }
  }
})

# Initial detection on load
$form.Add_Shown({
  Log "PLM Environment Admin GUI started (Admin)."
  Log "Tip: Click Detect. If missing components, click Install/Repair. For updates, click Update."
  $s = Detect-Environment
  Render-Status $s
})

[void]$form.ShowDialog()

