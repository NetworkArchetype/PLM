<# PLM-AdminConsoleGUI.ps1
   Admin GUI launcher for interacting with the environment deployed by prior scripts.
   Uses WinForms (built-in) — no external dependencies.
#>

[CmdletBinding()]
param(
  # Folder where Deploy-PLM-Environment.ps1 and Install-PLM-Code.ps1 live
  [string]$ScriptsDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-File",$PSCommandPath)
    if ($ScriptsDir) { $args += @("-ScriptsDir", $ScriptsDir) }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args | Out-Null
    exit 0
  }
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

function Resolve-ScriptsDir {
  if ($ScriptsDir -and (Test-Path $ScriptsDir)) { return (Resolve-Path $ScriptsDir).Path }
  return ""
}

Ensure-Admin
$ScriptsDir = Resolve-ScriptsDir

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----------------------------
# Helpers
# ----------------------------
function Log([string]$msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $textbox.AppendText("[$ts] $msg`r`n")
  $textbox.SelectionStart = $textbox.TextLength
  $textbox.ScrollToCaret()
}

function Run-Detached([string]$file, [string]$args, [switch]$Admin) {
  try {
    if ($Admin) {
      Start-Process -FilePath $file -ArgumentList $args -Verb RunAs | Out-Null
    } else {
      Start-Process -FilePath $file -ArgumentList $args | Out-Null
    }
    Log "Started: $file $args"
  } catch {
    Log "ERROR launching: $file $args -> $($_.Exception.Message)"
  }
}

function Run-InWindow([string]$title, [string]$commandLine) {
  # Creates a new PowerShell window that stays open
  $args = "-NoExit -Command `"Write-Host '$title' -ForegroundColor Cyan; $commandLine`""
  Run-Detached -file "powershell.exe" -args $args -Admin
}

function Run-Script([string]$scriptName) {
  if (-not $ScriptsDir) {
    [System.Windows.Forms.MessageBox]::Show(
      "ScriptsDir not set. Use 'Set Scripts Folder' and point to the folder containing $scriptName",
      "Missing Scripts Folder",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    return
  }
  $path = Join-Path $ScriptsDir $scriptName
  if (-not (Test-Path $path)) {
    [System.Windows.Forms.MessageBox]::Show(
      "Could not find:`r`n$path",
      "Script Not Found",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
  }

  $cmd = "Set-Location `"$ScriptsDir`"; Set-ExecutionPolicy Bypass -Scope Process -Force; .\`"$scriptName`""
  Run-InWindow -title "Running $scriptName" -commandLine $cmd
}

function Quick-Check {
  Log "Running quick checks..."

  try {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    Log ("WSL: " + ($(if ($wsl) { "OK" } else { "NOT FOUND" })))
  } catch { Log "WSL check failed." }

  try {
    $docker = Get-Command docker.exe -ErrorAction SilentlyContinue
    if ($docker) {
      $v = (docker version --format '{{.Server.Version}}' 2>$null)
      Log ("Docker: OK (server " + $v + ")")
    } else { Log "Docker: NOT FOUND" }
  } catch { Log ("Docker check error: " + $_.Exception.Message) }

  try {
    $py = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($py) {
      $pv = (python --version 2>$null)
      Log ("Python: " + $pv)
    } else { Log "Python: NOT FOUND" }
  } catch { Log ("Python check error: " + $_.Exception.Message) }

  try {
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
      Log "nvidia-smi: OK (Windows)"
    } else {
      Log "nvidia-smi: not found on Windows PATH"
    }
  } catch { Log ("nvidia-smi check error: " + $_.Exception.Message) }
}

# ----------------------------
# UI
# ----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "PLM Admin Console GUI"
$form.Size = New-Object System.Drawing.Size(980, 680)
$form.StartPosition = "CenterScreen"
$form.TopMost = $false

$font = New-Object System.Drawing.Font("Segoe UI", 10)

# Top panel
$top = New-Object System.Windows.Forms.Panel
$top.Dock = "Top"
$top.Height = 190
$form.Controls.Add($top)

# Scripts dir label + button
$lblScripts = New-Object System.Windows.Forms.Label
$lblScripts.Text = "Scripts Folder:"
$lblScripts.Location = New-Object System.Drawing.Point(12, 12)
$lblScripts.AutoSize = $true
$lblScripts.Font = $font
$top.Controls.Add($lblScripts)

$txtScripts = New-Object System.Windows.Forms.TextBox
$txtScripts.Location = New-Object System.Drawing.Point(120, 10)
$txtScripts.Size = New-Object System.Drawing.Size(650, 26)
$txtScripts.Font = $font
$txtScripts.Text = $ScriptsDir
$top.Controls.Add($txtScripts)

$btnPickScripts = New-Object System.Windows.Forms.Button
$btnPickScripts.Text = "Set Scripts Folder"
$btnPickScripts.Location = New-Object System.Drawing.Point(780, 8)
$btnPickScripts.Size = New-Object System.Drawing.Size(170, 30)
$btnPickScripts.Font = $font
$top.Controls.Add($btnPickScripts)

# Row: shells
$btnPS = New-Object System.Windows.Forms.Button
$btnPS.Text = "Open Admin PowerShell"
$btnPS.Location = New-Object System.Drawing.Point(12, 52)
$btnPS.Size = New-Object System.Drawing.Size(210, 35)
$btnPS.Font = $font
$top.Controls.Add($btnPS)

$btnCMD = New-Object System.Windows.Forms.Button
$btnCMD.Text = "Open Admin CMD"
$btnCMD.Location = New-Object System.Drawing.Point(232, 52)
$btnCMD.Size = New-Object System.Drawing.Size(160, 35)
$btnCMD.Font = $font
$top.Controls.Add($btnCMD)

$btnWT = New-Object System.Windows.Forms.Button
$btnWT.Text = "Open Windows Terminal"
$btnWT.Location = New-Object System.Drawing.Point(402, 52)
$btnWT.Size = New-Object System.Drawing.Size(190, 35)
$btnWT.Font = $font
$top.Controls.Add($btnWT)

$btnWSL = New-Object System.Windows.Forms.Button
$btnWSL.Text = "Open WSL (Ubuntu)"
$btnWSL.Location = New-Object System.Drawing.Point(602, 52)
$btnWSL.Size = New-Object System.Drawing.Size(180, 35)
$btnWSL.Font = $font
$top.Controls.Add($btnWSL)

$btnDockerShell = New-Object System.Windows.Forms.Button
$btnDockerShell.Text = "Docker: Run Bash"
$btnDockerShell.Location = New-Object System.Drawing.Point(792, 52)
$btnDockerShell.Size = New-Object System.Drawing.Size(158, 35)
$btnDockerShell.Font = $font
$top.Controls.Add($btnDockerShell)

# Row: run scripts
$btnDeploy = New-Object System.Windows.Forms.Button
$btnDeploy.Text = "Run Deploy-PLM-Environment.ps1"
$btnDeploy.Location = New-Object System.Drawing.Point(12, 98)
$btnDeploy.Size = New-Object System.Drawing.Size(310, 35)
$btnDeploy.Font = $font
$top.Controls.Add($btnDeploy)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Run Install-PLM-Code.ps1"
$btnInstall.Location = New-Object System.Drawing.Point(332, 98)
$btnInstall.Size = New-Object System.Drawing.Size(260, 35)
$btnInstall.Font = $font
$top.Controls.Add($btnInstall)

$btnSmokeNative = New-Object System.Windows.Forms.Button
$btnSmokeNative.Text = "Task: PLM Native Smoke (VS Code)"
$btnSmokeNative.Location = New-Object System.Drawing.Point(602, 98)
$btnSmokeNative.Size = New-Object System.Drawing.Size(248, 35)
$btnSmokeNative.Font = $font
$top.Controls.Add($btnSmokeNative)

$btnSmokeDocker = New-Object System.Windows.Forms.Button
$btnSmokeDocker.Text = "Task: PLM Docker Smoke (VS Code)"
$btnSmokeDocker.Location = New-Object System.Drawing.Point(860, 98)
$btnSmokeDocker.Size = New-Object System.Drawing.Size(90, 35)
$btnSmokeDocker.Font = $font
$top.Controls.Add($btnSmokeDocker)

# Row: utilities
$btnOpenRepo = New-Object System.Windows.Forms.Button
$btnOpenRepo.Text = "Open Repo Folder"
$btnOpenRepo.Location = New-Object System.Drawing.Point(12, 142)
$btnOpenRepo.Size = New-Object System.Drawing.Size(160, 35)
$btnOpenRepo.Font = $font
$top.Controls.Add($btnOpenRepo)

$btnOpenVSCode = New-Object System.Windows.Forms.Button
$btnOpenVSCode.Text = "Open VS Code Workspace"
$btnOpenVSCode.Location = New-Object System.Drawing.Point(182, 142)
$btnOpenVSCode.Size = New-Object System.Drawing.Size(210, 35)
$btnOpenVSCode.Font = $font
$top.Controls.Add($btnOpenVSCode)

$btnChecks = New-Object System.Windows.Forms.Button
$btnChecks.Text = "Quick Checks"
$btnChecks.Location = New-Object System.Drawing.Point(402, 142)
$btnChecks.Size = New-Object System.Drawing.Size(130, 35)
$btnChecks.Font = $font
$top.Controls.Add($btnChecks)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Log"
$btnClear.Location = New-Object System.Drawing.Point(542, 142)
$btnClear.Size = New-Object System.Drawing.Size(110, 35)
$btnClear.Font = $font
$top.Controls.Add($btnClear)

# Log textbox
$textbox = New-Object System.Windows.Forms.TextBox
$textbox.Multiline = $true
$textbox.ScrollBars = "Vertical"
$textbox.Dock = "Fill"
$textbox.Font = New-Object System.Drawing.Font("Consolas", 10)
$textbox.ReadOnly = $true
$form.Controls.Add($textbox)

# ----------------------------
# Events
# ----------------------------
$btnPickScripts.Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Select folder containing Deploy-PLM-Environment.ps1 and Install-PLM-Code.ps1"
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $ScriptsDir = $dlg.SelectedPath
    $txtScripts.Text = $ScriptsDir
    Log "Scripts folder set: $ScriptsDir"
  }
})

$btnPS.Add_Click({ Run-Detached -file "powershell.exe" -args "-NoProfile" -Admin })
$btnCMD.Add_Click({ Run-Detached -file "cmd.exe" -args "" -Admin })
$btnWT.Add_Click({
  # Windows Terminal may not always elevate; opens WT, user can open elevated profile.
  Run-Detached -file "wt.exe" -args "" -Admin:$false
})
$btnWSL.Add_Click({ Run-Detached -file "wsl.exe" -args "-d Ubuntu" -Admin:$false })

$btnDockerShell.Add_Click({
  # Start interactive bash in the PLM docker image if it exists.
  $img = "networkarchetype-plm:latest"
  Run-InWindow -title "Docker Bash ($img)" -commandLine "docker run --rm -it $img bash"
})

$btnDeploy.Add_Click({
  $ScriptsDir = $txtScripts.Text
  Run-Script "Deploy-PLM-Environment.ps1"
})

$btnInstall.Add_Click({
  $ScriptsDir = $txtScripts.Text
  Run-Script "Install-PLM-Code.ps1"
})

$btnChecks.Add_Click({ Quick-Check })
$btnClear.Add_Click({ $textbox.Clear() })

$btnOpenRepo.Add_Click({
  # If ScriptsDir looks like the place you stored scripts, try to find a sibling repo folder.
  $d = $txtScripts.Text
  if ($d -and (Test-Path $d)) {
    # Common layout: <root>\repos\PLM
    $rootGuess = Split-Path $d -Parent
    $repoGuess = Join-Path $rootGuess "repos\PLM"
    if (Test-Path $repoGuess) {
      Run-Detached -file "explorer.exe" -args "`"$repoGuess`"" -Admin:$false
      Log "Opened repo: $repoGuess"
      return
    }
    Run-Detached -file "explorer.exe" -args "`"$d`"" -Admin:$false
    Log "Opened folder: $d"
  } else {
    [System.Windows.Forms.MessageBox]::Show("Set Scripts Folder first.", "Info") | Out-Null
  }
})

$btnOpenVSCode.Add_Click({
  $code = Find-CodeCmd
  if (-not $code) {
    [System.Windows.Forms.MessageBox]::Show("VS Code CLI not found yet. Launch VS Code once.", "Info") | Out-Null
    return
  }

  # Search upward from scripts dir for PLM.code-workspace
  $d = $txtScripts.Text
  if (-not $d -or -not (Test-Path $d)) {
    [System.Windows.Forms.MessageBox]::Show("Set Scripts Folder first.", "Info") | Out-Null
    return
  }

  $rootGuess = Split-Path $d -Parent
  $ws = Join-Path $rootGuess "PLM.code-workspace"
  if (Test-Path $ws) {
    Run-Detached -file $code -args "`"$ws`"" -Admin:$false
    Log "Opened workspace: $ws"
  } else {
    # fallback: open repo
    $repoGuess = Join-Path $rootGuess "repos\PLM"
    if (Test-Path $repoGuess) {
      Run-Detached -file $code -args "`"$repoGuess`"" -Admin:$false
      Log "Opened repo in VS Code: $repoGuess"
    } else {
      [System.Windows.Forms.MessageBox]::Show("Could not find workspace or repo from your scripts folder. Open manually.", "Info") | Out-Null
    }
  }
})

$btnSmokeNative.Add_Click({
  # Runs VS Code task if code CLI exists; otherwise uses direct PowerShell.
  $code = Find-CodeCmd
  if (-not $code) {
    [System.Windows.Forms.MessageBox]::Show("VS Code CLI not found. Launch VS Code once.", "Info") | Out-Null
    return
  }
  $d = $txtScripts.Text
  $rootGuess = Split-Path $d -Parent
  $repoGuess = Join-Path $rootGuess "repos\PLM"
  if (-not (Test-Path $repoGuess)) {
    [System.Windows.Forms.MessageBox]::Show("Repo not found at: $repoGuess", "Info") | Out-Null
    return
  }
  Run-Detached -file $code -args "`"$repoGuess`" --command `"workbench.action.tasks.runTask`"" -Admin:$false
  Log "Opened VS Code task runner (select PLM: Native smoke test)."
})

$btnSmokeDocker.Add_Click({
  # Simple direct docker smoke run (if image exists)
  Run-InWindow -title "Docker Smoke Test" -commandLine "docker run --rm networkarchetype-plm:latest"
})

# Initial log
Log "PLM Admin Console GUI started (Admin)."
if ($ScriptsDir) { Log "ScriptsDir: $ScriptsDir" } else { Log "ScriptsDir not set (use Set Scripts Folder)." }
Log "Tip: Run Deploy script first, then Install script."

[void]$form.ShowDialog()
# End of PLM-AdminConsoleGUI.ps1