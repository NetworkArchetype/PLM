<#  PLM-Environment-AdminGUI.fixed.ps1
    Admin GUI to detect + manage the environment deployed by Deploy-PLM-Environment.ps1.
    WinForms GUI (built-in), runs elevated, supports Native/WSL/Docker/Hyper-V modes.
#>

[CmdletBinding()]
param(
  [string]$DeployScriptPath = ""   # optional: full path to Deploy-PLM-Environment.ps1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Predeclare $n to avoid StrictMode crashes if any event handler or profile code references it unexpectedly
$script:n = $null
# Predeclare $Name as well to guard against any late-bound references under StrictMode
$script:Name = "unknown"

$script:RepoRoot = Split-Path $PSScriptRoot -Parent
$script:IsAdvancedMode = $false
$script:SessionId = [guid]::NewGuid().ToString()
$script:ContextPath = Join-Path $script:RepoRoot ".plm_session.ndjson"

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

# WinForms needs STA; if not STA, relaunch this script with -STA and same args
function Ensure-STA {
  $apartment = [System.Threading.Thread]::CurrentThread.ApartmentState
  if ($apartment -ne "STA") {
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-STA","-File",$PSCommandPath)
    if ($DeployScriptPath) { $args += @("-DeployScriptPath", $DeployScriptPath) }
    Start-Process powershell.exe -ArgumentList $args -Verb RunAs | Out-Null
    exit 0
  }
}
Ensure-STA

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------
# Logging (defined after UI textbox exists, but keep helper)
# -----------------------------
$script:txtLog = $null
$script:txtLogPopup = $null

function Append-ContextLog([string]$msg) {
  try {
    $ts = (Get-Date).ToString("s")
    $line = @{ ts = $ts; session = $script:SessionId; source = "gui"; user = $env:USERNAME; msg = $msg } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $script:ContextPath -Value $line
    Write-StoreEvent -Kind "context" -Message $msg -Payload @{ ts = $ts; context = $msg }
  } catch {}
}

function Write-StoreEvent {
  param(
    [string]$Kind,
    [string]$Message,
    $Payload
  )
  try {
    $py = Get-PythonExe
  } catch { $py = $null }
  if (-not $py) { return }
  $store = Join-Path $script:RepoRoot "scripts/plm_store.py"
  if (-not (Test-Path $store)) { return }

  $tmp = $null
  try {
    $args = @($py, $store, "log", "--engine", "auto", "--source", "gui", "--kind", $Kind, "--msg", $Message, "--session", $script:SessionId, "--user", $env:USERNAME)
    if ($Payload) {
      $tmp = [System.IO.Path]::GetTempFileName()
      $Payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $tmp -Encoding UTF8
      $args += @("--payload-file", $tmp)
    }
    & $args | Out-Null
  } catch {
    # logging should never block the GUI
  } finally {
    if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -ErrorAction SilentlyContinue }
  }
}

function Get-LastSessionInfo {
  try {
    if (-not (Test-Path $script:ContextPath)) { return $null }
    $last = Get-Content -LiteralPath $script:ContextPath -Tail 1
    if (-not $last) { return $null }
    return ($last | ConvertFrom-Json)
  } catch { return $null }
}

function Get-ContextTail([int]$Count = 120) {
  if (-not (Test-Path $script:ContextPath)) { return @() }
  try {
    return (Get-Content -LiteralPath $script:ContextPath -Tail $Count | ForEach-Object {
      try { $_ | ConvertFrom-Json } catch { $null }
    }) | Where-Object { $_ }
  } catch { return @() }
}

function Format-ContextEntry($entry) {
  if (-not $entry) { return "" }
  $ts = $entry.ts
  $user = $(if ($entry.user) { $entry.user } else { "?" })
  $src = $(if ($entry.source) { $entry.source } else { "?" })
  $msg = $entry.msg
  return "[$ts] ($user/$src) $msg"
}

function Build-PopupLogText {
  $lines = @()
  if ($script:txtLog) {
    $lines += $script:txtLog.Text.TrimEnd("`r","`n").Split("`n")
  }
  $ctx = Get-ContextTail 80
  if ($ctx.Count -gt 0) {
    $lines += ""
    $lines += "---- Shared context (last $($ctx.Count)) ----"
    foreach ($c in $ctx) { $lines += (Format-ContextEntry $c) }
  }
  return ($lines -join "`r`n")
}

function Sync-PopupLog {
  if (-not $script:txtLogPopup) { return }
  $text = Build-PopupLogText
  $script:txtLogPopup.TextBox.Text = $text
  $script:txtLogPopup.TextBox.SelectionStart = $script:txtLogPopup.TextBox.TextLength
  $script:txtLogPopup.TextBox.ScrollToCaret()
}

function Check-Collision([int]$Minutes = 30) {
  $tail = Get-ContextTail 200
  if (-not $tail -or $tail.Count -eq 0) { return }
  $cutoff = (Get-Date).AddMinutes(-$Minutes)
  $hits = @()
  foreach ($e in $tail) {
    try {
      if (-not $e.ts) { continue }
      $dt = [datetime]::Parse($e.ts)
      if ($dt -lt $cutoff) { continue }
      $user = $(if ($e.user) { $e.user } else { "?" })
      if ($user -ne $env:USERNAME -or ($e.session -and $e.session -ne $script:SessionId)) {
        $hits += $e
      }
    } catch {}
  }
  if ($hits.Count -gt 0) {
    $latest = $hits[-1]
    $u = $(if ($latest.user) { $latest.user } else { "unknown" })
    $t = $latest.ts
    Log "Heads-up: another session ($u) active recently at $t."
    # Do not block with a message box; allow multiple instances without modal dialogs
  }
}

function Sanitize-LogMessage([string]$msg) {
  if (-not $msg) { return $msg }

  $out = $msg
  # Common token/key patterns
  $out = $out -replace '\bghp_[A-Za-z0-9]{36}\b', 'ghp_REDACTED'
  $out = $out -replace '\bgithub_pat_[A-Za-z0-9_]{20,}\b', 'github_pat_REDACTED'
  $out = $out -replace '(?i)\bBearer\s+[A-Za-z0-9\-_.=]{12,}\b', 'Bearer REDACTED'
  $out = $out -replace '(?i)\b(Authorization\s*:\s*Bearer)\s+\S+', '$1 REDACTED'
  # Common assignment forms (best-effort; avoids logging real values)
  $out = $out -replace '(?i)\b(password|passwd|pwd)\b\s*[:=]\s*[^\s;]+', '$1=REDACTED'
  $out = $out -replace '(?i)\b(token|secret|api[_-]?key|client_secret)\b\s*[:=]\s*[^\s;]+', '$1=REDACTED'
  return $out
}

function Log([string]$msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $msg = Sanitize-LogMessage $msg
    Append-ContextLog $msg
  if ($script:txtLog) {
    $script:txtLog.AppendText("[$ts] $msg`r`n")
    $script:txtLog.SelectionStart = $script:txtLog.TextLength
    $script:txtLog.ScrollToCaret()
    if ($script:txtLogPopup) {
      $script:txtLogPopup.TextBox.AppendText("[$ts] $msg`r`n")
      $script:txtLogPopup.TextBox.SelectionStart = $script:txtLogPopup.TextBox.TextLength
      $script:txtLogPopup.TextBox.ScrollToCaret()
    }
  } else {
    Write-Host "[$ts] $msg"
  }
}

# Helper to wrap UI actions and avoid unhandled exceptions bringing down the form
function Invoke-UiAction {
  param(
    [string]$Name = "unknown",
    [ScriptBlock]$Action
  )
  # Suppress StrictMode inside handler execution to avoid crashes on any unexpected late-bound vars
  Set-StrictMode -Off
  $label = $(if ($PSBoundParameters.ContainsKey('Name') -and $Name) { $Name } else { "unknown" })
  try {
    Log "Action '$label' starting..."
    Write-StoreEvent -Kind "ui" -Message "gui:$label:start" -Payload @{}
    & $Action
    Write-StoreEvent -Kind "ui" -Message "gui:$label:ok" -Payload @{}
  } catch {
    $err = $_.Exception.Message
    Log "Action '$label' failed: $err"
    Write-StoreEvent -Kind "ui" -Message "gui:$label:fail" -Payload @{ error = $err }
    [System.Windows.Forms.MessageBox]::Show("Action '$label' failed: $err","Action failed",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
  }
}

function Wrap-UiAction {
  param(
    [string]$Name = "unknown",
    [ScriptBlock]$Action
  )
  # Capture fixed values into a closure to avoid unbound variables at handler runtime
  $label = if ($PSBoundParameters.ContainsKey('Name') -and $Name) { $Name } else { "unknown" }
  $localAction = $Action.GetNewClosure()
  $localLabel = $label
  return ({ param($sender,$eventArgs) Invoke-UiAction -Name $localLabel -Action $localAction }).GetNewClosure()
}

function Exists-Cmd([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Winget-Ok { Exists-Cmd "winget" }

# GitHub CLI helpers
function Get-GhPath {
  try {
    $c = Get-Command gh -ErrorAction SilentlyContinue
    if ($c) { return $c.Path }
    # Try common install locations
    $candidates = @(
      "$env:ProgramFiles\GitHub CLI\bin\gh.exe",
      "$env:LOCALAPPDATA\Programs\GitHub CLI\bin\gh.exe",
      "$env:ProgramFiles(x86)\GitHub CLI\bin\gh.exe"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { $dir = Split-Path $p -Parent; $env:Path = "$env:Path;$dir"; return $p } }
    return $null
  } catch { return $null }
}

function Exists-Gh { return [bool](Get-GhPath) }

function Gh-AuthStatus {
  $gh = Get-GhPath
  if (-not $gh) { return $false }
  try {
    & $gh auth status --hostname github.com > $null 2>&1
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

function Get-GhUser {
  $gh = Get-GhPath
  if (-not $gh) { return $null }
  try {
    $user = & $gh api user --jq .login 2>$null
    return $user.Trim()
  } catch { return $null }
}

function Do-GhInstall {
  if (-not (Winget-Ok)) { Log "winget missing; cannot install GitHub CLI."; [System.Windows.Forms.MessageBox]::Show("winget not found. Please install GitHub CLI manually from https://cli.github.com/","Install GH",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
  try {
    Log "Installing GitHub CLI via winget..."
    winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements | Out-Host
    Start-Sleep -Seconds 2
    $gh = Get-GhPath
    if ($gh) { Log "GitHub CLI installed: $gh"; [System.Windows.Forms.MessageBox]::Show("GitHub CLI installed. Click 'GitHub Login' to authenticate.","Install GH",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null } else { Log "GitHub CLI install attempted but gh not found on PATH."; [System.Windows.Forms.MessageBox]::Show("GitHub CLI installed but not found in PATH. You may need to restart your shell.","Install GH",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null }
  } catch { Log "GitHub CLI install failed: $($_.Exception.Message)"; [System.Windows.Forms.MessageBox]::Show("GitHub CLI installation failed. Install manually from https://cli.github.com/","Install GH",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null }
}

function Do-GhLogin {
  $gh = Get-GhPath
  if (-not $gh) {
    $res = [System.Windows.Forms.MessageBox]::Show("GitHub CLI is not installed. Install it now via winget?","GitHub CLI missing",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
    if ($res -eq [System.Windows.Forms.DialogResult]::Yes) { Do-GhInstall; Start-Sleep -Seconds 2 }
    $gh = Get-GhPath
    if (-not $gh) { [System.Windows.Forms.MessageBox]::Show("Install failed or not available. Please install manually: https://cli.github.com/","Install GH", [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
  }

  if (Gh-AuthStatus) { [System.Windows.Forms.MessageBox]::Show("GitHub CLI already authenticated.","GitHub Login",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null; return }

  # Run interactive login in a normal PowerShell (not elevated) because gh stores credentials per-user
  Start-Process powershell.exe -ArgumentList "-NoExit","-Command","gh auth login --web" | Out-Null
  Log "Launched GitHub login (gh auth login --web) in PowerShell (interactive)."
}

function Update-GhStatusLabel {
  if (-not $script:lblGitHubStatus) { return }
  if (-not (Exists-Gh)) { $script:lblGitHubStatus.ForeColor = Status-Color $false; $script:lblGitHubStatus.Text = "Not installed"; return }
  if (Gh-AuthStatus) { $u = Get-GhUser; if ($u) { $script:lblGitHubStatus.ForeColor = Status-Color $true; $script:lblGitHubStatus.Text = "Logged in: $u" } else { $script:lblGitHubStatus.ForeColor = Status-Color $true; $script:lblGitHubStatus.Text = "Authenticated" } } else { $script:lblGitHubStatus.ForeColor = Status-Color $false; $script:lblGitHubStatus.Text = "Not logged in" }
}

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
    CUDA           = Exists-Cmd "nvcc"
  }
  return $state
}

function Status-Color($ok) {
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
$script:lblCUDAValue = $null

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

  if ($script:lblCUDAValue) {
    $script:lblCUDAValue.ForeColor = Status-Color $s.CUDA
    $script:lblCUDAValue.Text      = $(if ($s.CUDA){"OK"} else {"Not found"})
  }
}

# -----------------------------
# Diagnostics helpers
# -----------------------------
function Set-AdvancedMode([bool]$enable) {
  $script:IsAdvancedMode = $enable
  if ($enable) {
    Log "Advanced debug mode (option 2) enabled: full pytest + deep probes will be allowed."
  } else {
    Log "Guided mode enabled: use quick smoke + safe actions."
  }
}

function Get-PythonExe {
  $candidates = @(
    (Join-Path $RepoRoot "venv\\Scripts\\python.exe"),
    "python"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c -or (Exists-Cmd $c)) { return $c }
  }
  return $null
}

function Run-SmokeTest([switch]$Full) {
  $python = Get-PythonExe
  if (-not $python) { Log "Python not found. Click Install/Repair first."; return }

  $label = $(if ($Full) { "Full pytest suite" } else { "Quick smoke test (test_installation.py)" })
  Log "Running $label using: $python"

  Push-Location $RepoRoot
  try {
    if ($Full) {
      & $python -m pytest 2>&1 | ForEach-Object { Log $_ }
    } else {
      & $python test_installation.py 2>&1 | ForEach-Object { Log $_ }
    }
    Log "Diagnostics finished (exit code: $LASTEXITCODE)."
    Append-ContextLog "diag:exit=$LASTEXITCODE full=$Full"
    Write-StoreEvent -Kind "diagnostic" -Message "gui:smoke" -Payload @{ exit_code = $LASTEXITCODE; full = [bool]$Full }
  } catch {
    Log "Diagnostics run failed: $($_.Exception.Message)"
    Append-ContextLog "diag:error=$($_.Exception.Message)"
    Write-StoreEvent -Kind "diagnostic" -Message "gui:smoke:error" -Payload @{ error = $($_.Exception.Message); full = [bool]$Full }
  } finally {
    Pop-Location
  }
}

function Run-CUDADiagnostics {
  Log "Running CUDA / GPU probe..."
  if (-not (Exists-Cmd "nvidia-smi")) { Log "nvidia-smi not found. Install NVIDIA drivers."; return }
  try {
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" } | Select-Object -First 1
    if ($gpu) { Log "Detected GPU: $($gpu.Name)" } else { Log "No NVIDIA GPU detected." }
  } catch { Log "GPU detection error: $($_.Exception.Message)" }

  if (Exists-Cmd "nvcc") {
    try {
      $nvccVersion = & nvcc --version 2>$null | Select-String "release" | ForEach-Object { $_.Line }
      Log "nvcc: $nvccVersion"
    } catch { Log "nvcc query failed: $($_.Exception.Message)" }
  } else {
    Log "CUDA toolkit (nvcc) not found."
  }

  try {
    $smi = & nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits 2>$null
    Log "GPU Info: $smi"
  } catch { Log "nvidia-smi query failed: $($_.Exception.Message)" }
  Log "CUDA probe complete."
  Append-ContextLog "cuda-probe-done"
  Write-StoreEvent -Kind "probe" -Message "gui:cuda" -Payload @{ gpu = $gpu; nvcc = $nvccVersion; smi = $smi }
}

function Run-EnvReport {
  Log "Collecting environment report..."
  $s = Detect-Environment
  Render-Status $s
  $report = $s.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key,$_.Value }
  Log ("Env: " + ($report -join "; "))
}

function Export-DebugReport {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $path = Join-Path ([System.IO.Path]::GetTempPath()) "plm-debug-$stamp.log"
  $lines = @()
  $lines += "PLM Debug Report $stamp"
  $lines += "Repo: $RepoRoot"
  $lines += "AdvancedMode: $script:IsAdvancedMode"
  $lines += ""
  $state = Detect-Environment
  $lines += "Environment:" + ($state.GetEnumerator() | ForEach-Object { " {0}={1}" -f $_.Key,$_.Value }) -join ""
  $lines += ""
  try {
    $python = Get-PythonExe
    if ($python) { $lines += "Python: $python" }
    Push-Location $RepoRoot
    try {
      $pipLine = & $python -m pip show plm-formalized 2>$null | Out-String
      if ($pipLine) { $lines += "plm-formalized:`n$($pipLine.Trim())" }
    } catch {}
  } finally { Pop-Location }
  $lines += ""
  $lines | Out-File -FilePath $path -Encoding utf8
  Log "Debug report written: $path"
}

function Open-DebugConsole([switch]$ActivateVenv) {
  $activateCmd = ""
  $venvActivate = Join-Path $RepoRoot "venv\\Scripts\\Activate.ps1"
  if ($ActivateVenv -and (Test-Path $venvActivate)) { $activateCmd = ". '$venvActivate'; " }
  $cmd = "& { Set-Location -LiteralPath '$RepoRoot'; $activateCmd Write-Host 'PLM debug console ready at $RepoRoot'; }"
  Start-Process powershell.exe -ArgumentList "-NoExit","-ExecutionPolicy","Bypass","-Command",$cmd | Out-Null
  Log "Opened debug console (venv activated: $ActivateVenv)"
}

function Open-ResourceMonitor {
  try {
    Start-Process perfmon.exe -ArgumentList "/res" | Out-Null
    Log "Opened Windows Resource Monitor."
  } catch {
    Log "Failed to open Resource Monitor: $($_.Exception.Message)"
  }
}

# -----------------------------
# Actions
# -----------------------------
function Do-InstallOrRepair {
  $s = Detect-Environment
  Render-Status $s
  Log "Starting Install/Repair..."

  if (-not $s.Winget) { Log "winget missing. Install 'App Installer' from Microsoft Store."; return }

  foreach ($id in @("Git.Git","Python.Python.3.12","Microsoft.VisualStudioCode","Microsoft.WindowsTerminal","Docker.DockerDesktop")) {
    try { Winget-Install $id; Log "Installed: $id" } catch { Log "Install failed: $id :: $($_.Exception.Message)" }
  }

  Log "Enabling WSL2 features..."
  try { dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null; Log "WSL feature enabled (or already enabled)." } catch { Log "WSL feature enable failed: $($_.Exception.Message)" }
  try { dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null; Log "VirtualMachinePlatform enabled (or already enabled)." } catch { Log "VMP enable failed: $($_.Exception.Message)" }

  if (Exists-Cmd "wsl") {
    try { wsl.exe --set-default-version 2 | Out-Host; Log "WSL default set to 2." } catch { Log "WSL set-default-version failed: $($_.Exception.Message)" }
    try { wsl.exe --install -d Ubuntu | Out-Host; Log "Ubuntu install triggered (or already installed)." } catch { Log "Ubuntu install may already exist / needs reboot: $($_.Exception.Message)" }
  }

  $codeCmd = Find-CodeCmd
  if ($codeCmd) {
    Log "Installing VS Code extensions..."
    try { Install-VSCodeExtensions $codeCmd; Log "VS Code extensions installed." } catch { Log "VS Code extensions failed: $($_.Exception.Message)" }
  } else {
    Log "VS Code CLI not detected yet (launch VS Code once, then rerun extensions)."
  }

  Log "Install/Repair finished. Reboot may be required if WSL features were newly enabled."
  Render-Status (Detect-Environment)
}

function Do-Update {
  $s = Detect-Environment
  Render-Status $s
  if (-not $s.Winget) { Log "winget missing; cannot update."; return }

  Log "Updating packages (winget upgrade)..."
  foreach ($id in @("Git.Git","Python.Python.3.12","Microsoft.VisualStudioCode","Microsoft.WindowsTerminal","Docker.DockerDesktop")) {
    try { Winget-Upgrade $id; Log "Upgraded: $id" } catch { Log "Upgrade failed: $id :: $($_.Exception.Message)" }
  }

  $codeCmd = Find-CodeCmd
  if ($codeCmd) {
    Log "Re-applying VS Code extensions (idempotent)..."
    try { Install-VSCodeExtensions $codeCmd; Log "VS Code extensions OK." } catch { Log "VS Code extensions failed: $($_.Exception.Message)" }
  }

  Render-Status (Detect-Environment)
  Log "Update finished."
}

function Do-RunDeployScript {
  if (-not $DeployScriptPath -or -not (Test-Path $DeployScriptPath)) {
    [System.Windows.Forms.MessageBox]::Show(
      "Deploy script not set or not found. Use 'Select' to choose Deploy-PLM-Environment.ps1 first.",
      "Missing Deploy Script",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    return
  }
  Log "Running deploy script: $DeployScriptPath"
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$DeployScriptPath | Out-Null
}

function Do-OpenHyperVManager {
  if (Test-Path "$env:WINDIR\System32\virtmgmt.msc") {
    Start-Process mmc.exe -Verb RunAs -ArgumentList "$env:WINDIR\System32\virtmgmt.msc" | Out-Null
    Log "Opened Hyper-V Manager."
  } else {
    Log "Hyper-V Manager not found (Hyper-V may be unavailable on this edition)."
  }
}
function Do-CreateHyperVSandboxNote {
  $msg = @(
    "Hyper-V Sandbox Mode (GUI):",
    "- Click 'Open Hyper-V' to create/manage a VM.",
    "- Install Windows/Ubuntu in the VM from an ISO.",
    "- Run Deploy-PLM-Environment.ps1 inside the VM for an isolated sandbox.",
    "",
    "Tip: Docker + WSL are the fastest sandboxes; Hyper-V is full OS isolation."
  ) -join "`r`n"
  [System.Windows.Forms.MessageBox]::Show($msg, "Hyper-V Sandbox Help",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

# -----------------------------
# GUI
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "PLM Environment Admin GUI (Native / WSL / Docker / Hyper-V)"
$form.Size = New-Object System.Drawing.Size(1100, 740)
$form.StartPosition = "CenterScreen"

$font = New-Object System.Drawing.Font("Segoe UI", 10)

$pTop = New-Object System.Windows.Forms.Panel
$pTop.Dock = "Top"
$pTop.Height = 300
$form.Controls.Add($pTop)

$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = "Environment Detection"
$grpStatus.Font = $font
$grpStatus.Location = New-Object System.Drawing.Point(12, 10)
$grpStatus.Size = New-Object System.Drawing.Size(520, 270)
$pTop.Controls.Add($grpStatus)

# Status rows (expanded inline to avoid parser issues). ASCII only to dodge encoding glitches.
$lblWinget = New-Object System.Windows.Forms.Label
$lblWinget.Text = "winget"
$lblWinget.Location = New-Object System.Drawing.Point(16, 30)
$lblWinget.Size = New-Object System.Drawing.Size(210, 22)
$lblWinget.Font = $font
$grpStatus.Controls.Add($lblWinget)
$script:lblWingetValue = New-Object System.Windows.Forms.Label
$script:lblWingetValue.Text = "-"
$script:lblWingetValue.Location = New-Object System.Drawing.Point(240, 30)
$script:lblWingetValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblWingetValue.Font = $font
$grpStatus.Controls.Add($script:lblWingetValue)

$lblGit = New-Object System.Windows.Forms.Label
$lblGit.Text = "Git"
$lblGit.Location = New-Object System.Drawing.Point(16, 55)
$lblGit.Size = New-Object System.Drawing.Size(210, 22)
$lblGit.Font = $font
$grpStatus.Controls.Add($lblGit)
$script:lblGitValue = New-Object System.Windows.Forms.Label
$script:lblGitValue.Text = "-"
$script:lblGitValue.Location = New-Object System.Drawing.Point(240, 55)
$script:lblGitValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblGitValue.Font = $font
$grpStatus.Controls.Add($script:lblGitValue)

$lblPython = New-Object System.Windows.Forms.Label
$lblPython.Text = "Python"
$lblPython.Location = New-Object System.Drawing.Point(16, 80)
$lblPython.Size = New-Object System.Drawing.Size(210, 22)
$lblPython.Font = $font
$grpStatus.Controls.Add($lblPython)
$script:lblPythonValue = New-Object System.Windows.Forms.Label
$script:lblPythonValue.Text = "-"
$script:lblPythonValue.Location = New-Object System.Drawing.Point(240, 80)
$script:lblPythonValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblPythonValue.Font = $font
$grpStatus.Controls.Add($script:lblPythonValue)

$lblVSCode = New-Object System.Windows.Forms.Label
$lblVSCode.Text = "VS Code (any version)"
$lblVSCode.Location = New-Object System.Drawing.Point(16, 105)
$lblVSCode.Size = New-Object System.Drawing.Size(210, 22)
$lblVSCode.Font = $font
$grpStatus.Controls.Add($lblVSCode)
$script:lblVSCodeValue = New-Object System.Windows.Forms.Label
$script:lblVSCodeValue.Text = "-"
$script:lblVSCodeValue.Location = New-Object System.Drawing.Point(240, 105)
$script:lblVSCodeValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblVSCodeValue.Font = $font
$grpStatus.Controls.Add($script:lblVSCodeValue)

$lblWT = New-Object System.Windows.Forms.Label
$lblWT.Text = "Windows Terminal"
$lblWT.Location = New-Object System.Drawing.Point(16, 130)
$lblWT.Size = New-Object System.Drawing.Size(210, 22)
$lblWT.Font = $font
$grpStatus.Controls.Add($lblWT)
$script:lblWTValue = New-Object System.Windows.Forms.Label
$script:lblWTValue.Text = "-"
$script:lblWTValue.Location = New-Object System.Drawing.Point(240, 130)
$script:lblWTValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblWTValue.Font = $font
$grpStatus.Controls.Add($script:lblWTValue)

$lblWSLFeat = New-Object System.Windows.Forms.Label
$lblWSLFeat.Text = "WSL2 Features"
$lblWSLFeat.Location = New-Object System.Drawing.Point(16, 155)
$lblWSLFeat.Size = New-Object System.Drawing.Size(210, 22)
$lblWSLFeat.Font = $font
$grpStatus.Controls.Add($lblWSLFeat)
$script:lblWSLFeatValue = New-Object System.Windows.Forms.Label
$script:lblWSLFeatValue.Text = "-"
$script:lblWSLFeatValue.Location = New-Object System.Drawing.Point(240, 155)
$script:lblWSLFeatValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblWSLFeatValue.Font = $font
$grpStatus.Controls.Add($script:lblWSLFeatValue)

$lblUbuntu = New-Object System.Windows.Forms.Label
$lblUbuntu.Text = "Ubuntu (WSL distro)"
$lblUbuntu.Location = New-Object System.Drawing.Point(16, 180)
$lblUbuntu.Size = New-Object System.Drawing.Size(210, 22)
$lblUbuntu.Font = $font
$grpStatus.Controls.Add($lblUbuntu)
$script:lblUbuntuValue = New-Object System.Windows.Forms.Label
$script:lblUbuntuValue.Text = "-"
$script:lblUbuntuValue.Location = New-Object System.Drawing.Point(240, 180)
$script:lblUbuntuValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblUbuntuValue.Font = $font
$grpStatus.Controls.Add($script:lblUbuntuValue)

$lblDocker = New-Object System.Windows.Forms.Label
$lblDocker.Text = "Docker Desktop"
$lblDocker.Location = New-Object System.Drawing.Point(16, 205)
$lblDocker.Size = New-Object System.Drawing.Size(210, 22)
$lblDocker.Font = $font
$grpStatus.Controls.Add($lblDocker)
$script:lblDockerValue = New-Object System.Windows.Forms.Label
$script:lblDockerValue.Text = "-"
$script:lblDockerValue.Location = New-Object System.Drawing.Point(240, 205)
$script:lblDockerValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblDockerValue.Font = $font
$grpStatus.Controls.Add($script:lblDockerValue)

# Nvidia row (extra)
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

# CUDA row (nvcc)
$lblCUDATitle = New-Object System.Windows.Forms.Label
$lblCUDATitle.Text = "CUDA Toolkit (nvcc)"
$lblCUDATitle.Location = New-Object System.Drawing.Point(16, 255)
$lblCUDATitle.Size = New-Object System.Drawing.Size(210, 22)
$lblCUDATitle.Font = $font
$grpStatus.Controls.Add($lblCUDATitle)

$script:lblCUDAValue = New-Object System.Windows.Forms.Label
$script:lblCUDAValue.Text = "-"
$script:lblCUDAValue.Location = New-Object System.Drawing.Point(240, 255)
$script:lblCUDAValue.Size = New-Object System.Drawing.Size(240, 22)
$script:lblCUDAValue.Font = $font
$grpStatus.Controls.Add($script:lblCUDAValue)

$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = "Actions and Modes"
$grpActions.Font = $font
$grpActions.Location = New-Object System.Drawing.Point(548, 10)
$grpActions.Size = New-Object System.Drawing.Size(520, 240)
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

# Detect/install/update/run deploy
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

# Diagnostics panel (sits between actions and log)
$pDiag = New-Object System.Windows.Forms.Panel
$pDiag.Dock = "Top"
$pDiag.Height = 150
$form.Controls.Add($pDiag)

$grpDiag = New-Object System.Windows.Forms.GroupBox
$grpDiag.Text = "Diagnostics and Debug"
$grpDiag.Font = $font
$grpDiag.Location = New-Object System.Drawing.Point(12, 0)
$grpDiag.Size = New-Object System.Drawing.Size(520, 140)
$pDiag.Controls.Add($grpDiag)

$lblUserMode = New-Object System.Windows.Forms.Label
$lblUserMode.Text = "User mode:"
$lblUserMode.Location = New-Object System.Drawing.Point(16, 28)
$lblUserMode.Size = New-Object System.Drawing.Size(90, 22)
$lblUserMode.Font = $font
$grpDiag.Controls.Add($lblUserMode)

$cmbUserMode = New-Object System.Windows.Forms.ComboBox
$cmbUserMode.Location = New-Object System.Drawing.Point(110, 26)
$cmbUserMode.Size = New-Object System.Drawing.Size(180, 28)
$cmbUserMode.Font = $font
$cmbUserMode.DropDownStyle = "DropDownList"
[void]$cmbUserMode.Items.Add("Guided (easy)")
[void]$cmbUserMode.Items.Add("Advanced debug (option 2)")
$cmbUserMode.SelectedIndex = 0
$grpDiag.Controls.Add($cmbUserMode)

$btnSmoke = New-Object System.Windows.Forms.Button
$btnSmoke.Text = "Run smoke test"
$btnSmoke.Location = New-Object System.Drawing.Point(16, 70)
$btnSmoke.Size = New-Object System.Drawing.Size(140, 32)
$btnSmoke.Font = $font
$grpDiag.Controls.Add($btnSmoke)

$btnPytest = New-Object System.Windows.Forms.Button
$btnPytest.Text = "Run full pytest (opt 2)"
$btnPytest.Location = New-Object System.Drawing.Point(166, 70)
$btnPytest.Size = New-Object System.Drawing.Size(180, 32)
$btnPytest.Font = $font
$grpDiag.Controls.Add($btnPytest)

$btnCudaProbe = New-Object System.Windows.Forms.Button
$btnCudaProbe.Text = "Probe CUDA/GPU"
$btnCudaProbe.Location = New-Object System.Drawing.Point(356, 70)
$btnCudaProbe.Size = New-Object System.Drawing.Size(150, 32)
$btnCudaProbe.Font = $font
$grpDiag.Controls.Add($btnCudaProbe)

$btnEnvReport = New-Object System.Windows.Forms.Button
$btnEnvReport.Text = "Refresh env report"
$btnEnvReport.Location = New-Object System.Drawing.Point(16, 106)
$btnEnvReport.Size = New-Object System.Drawing.Size(200, 28)
$btnEnvReport.Font = $font
$grpDiag.Controls.Add($btnEnvReport)

$grpDebug = New-Object System.Windows.Forms.GroupBox
$grpDebug.Text = "Consoles and Reports"
$grpDebug.Font = $font
$grpDebug.Location = New-Object System.Drawing.Point(548, 0)
$grpDebug.Size = New-Object System.Drawing.Size(520, 140)
$pDiag.Controls.Add($grpDebug)

$btnDebugConsole = New-Object System.Windows.Forms.Button
$btnDebugConsole.Text = "Open debug console"
$btnDebugConsole.Location = New-Object System.Drawing.Point(16, 28)
$btnDebugConsole.Size = New-Object System.Drawing.Size(180, 32)
$btnDebugConsole.Font = $font
$grpDebug.Controls.Add($btnDebugConsole)

$btnVenvConsole = New-Object System.Windows.Forms.Button
$btnVenvConsole.Text = "Option 2 console (venv)"
$btnVenvConsole.Location = New-Object System.Drawing.Point(206, 28)
$btnVenvConsole.Size = New-Object System.Drawing.Size(180, 32)
$btnVenvConsole.Font = $font
$grpDebug.Controls.Add($btnVenvConsole)

$btnExportReport = New-Object System.Windows.Forms.Button
$btnExportReport.Text = "Export debug report"
$btnExportReport.Location = New-Object System.Drawing.Point(396, 28)
$btnExportReport.Size = New-Object System.Drawing.Size(110, 32)
$btnExportReport.Font = $font
$grpDebug.Controls.Add($btnExportReport)

$btnMonitor = New-Object System.Windows.Forms.Button
$btnMonitor.Text = "Open Resource Monitor"
$btnMonitor.Location = New-Object System.Drawing.Point(16, 70)
$btnMonitor.Size = New-Object System.Drawing.Size(200, 32)
$btnMonitor.Font = $font
$grpDebug.Controls.Add($btnMonitor)

$btnPopLog = New-Object System.Windows.Forms.Button
$btnPopLog.Text = "Pop-out log window"
$btnPopLog.Location = New-Object System.Drawing.Point(226, 70)
$btnPopLog.Size = New-Object System.Drawing.Size(180, 32)
$btnPopLog.Font = $font
$grpDebug.Controls.Add($btnPopLog)

$btnDocs = New-Object System.Windows.Forms.Button
$btnDocs.Text = "Help / Docs"
$btnDocs.Location = New-Object System.Drawing.Point(416, 70)
$btnDocs.Size = New-Object System.Drawing.Size(90, 32)
$btnDocs.Font = $font
$grpDebug.Controls.Add($btnDocs)

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

# Hyper-V status display
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

$btnLaunchCLI = New-Object System.Windows.Forms.Button
$btnLaunchCLI.Text = "Switch to CLI"
$btnLaunchCLI.Location = New-Object System.Drawing.Point(16, 196)
$btnLaunchCLI.Size = New-Object System.Drawing.Size(110, 30)
$btnLaunchCLI.Font = $font
$grpActions.Controls.Add($btnLaunchCLI)

# Log box
$script:txtLog = New-Object System.Windows.Forms.TextBox
$script:txtLog.Multiline = $true
$script:txtLog.ReadOnly = $true
$script:txtLog.ScrollBars = "Vertical"
$script:txtLog.Dock = "Fill"
$script:txtLog.Font = New-Object System.Drawing.Font("Consolas", 10)
$form.Controls.Add($script:txtLog)

# -----------------------------
# Events
# -----------------------------
$btnPickDeploy.Add_Click( (Wrap-UiAction -Name "pick-deploy" -Action {
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
  $dlg.Title = "Select Deploy-PLM-Environment.ps1"
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $DeployScriptPath = $dlg.FileName
    $txtDeploy.Text = $DeployScriptPath
    Log "Deploy script set: $DeployScriptPath"
  }
}))

$btnDetect.Add_Click( (Wrap-UiAction -Name "detect" -Action {
  Log "Detecting environment..."
  $s = Detect-Environment
  Render-Status $s
  Write-StoreEvent -Kind "env" -Message "gui:env" -Payload $s
  Log ("Detected: " + (($s.GetEnumerator() | ForEach-Object { "$( $_.Key)=$( $_.Value)" }) -join "; "))
}))

$cmbUserMode.Add_SelectedIndexChanged( (Wrap-UiAction -Name "user-mode" -Action {
  $adv = ($cmbUserMode.SelectedIndex -eq 1)
  Set-AdvancedMode $adv
}))

$btnSmoke.Add_Click( (Wrap-UiAction -Name "smoke" -Action { Run-SmokeTest }) )

$btnPytest.Add_Click( (Wrap-UiAction -Name "pytest" -Action {
  if (-not $script:IsAdvancedMode) {
    $res = [System.Windows.Forms.MessageBox]::Show(
      "Full pytest is intended for advanced/option 2 users. Switch to advanced mode and continue?",
      "Advanced run",
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($res -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $cmbUserMode.SelectedIndex = 1
    Set-AdvancedMode $true
  }
  Run-SmokeTest -Full
}))

$btnCudaProbe.Add_Click( (Wrap-UiAction -Name "cuda-probe" -Action { Run-CUDADiagnostics }) )
$btnEnvReport.Add_Click( (Wrap-UiAction -Name "env-report" -Action { Run-EnvReport }) )

$btnDebugConsole.Add_Click( (Wrap-UiAction -Name "debug-console" -Action { Open-DebugConsole }) )
$btnVenvConsole.Add_Click( (Wrap-UiAction -Name "venv-console" -Action { Open-DebugConsole -ActivateVenv }) )
$btnExportReport.Add_Click( (Wrap-UiAction -Name "export-report" -Action { Export-DebugReport }) )
$btnMonitor.Add_Click( (Wrap-UiAction -Name "resource-monitor" -Action { Open-ResourceMonitor }) )
$btnPopLog.Add_Click( (Wrap-UiAction -Name "pop-log" -Action {
  if (-not $script:txtLogPopup) {
    $popup = New-Object System.Windows.Forms.Form
    $popup.Text = "PLM Log (pop-out)"
    $popup.Size = New-Object System.Drawing.Size(900, 500)
    $popup.StartPosition = "CenterParent"
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Multiline = $true
    $txt.ReadOnly = $true
    $txt.ScrollBars = "Vertical"
    $txt.Dock = "Fill"
    $txt.Font = New-Object System.Drawing.Font("Consolas", 10)
    $popup.Controls.Add($txt)
    $script:txtLogPopup = @{ Form = $popup; TextBox = $txt }
  }
  Sync-PopupLog
  $script:txtLogPopup.Form.ShowDialog() | Out-Null
}))

$btnDocs.Add_Click( (Wrap-UiAction -Name "docs" -Action {
  $docPath = Join-Path $script:RepoRoot "docs/Admin-GUI-and-CLI-Guide.md"
  if (Test-Path $docPath) {
    Start-Process $docPath | Out-Null
    Log "Opened operator guide."
  } else {
    Log "Operator guide not found."
  }
}))

$btnInstallRepair.Add_Click( (Wrap-UiAction -Name "install-repair" -Action { Do-InstallOrRepair }) )
$btnUpdate.Add_Click( (Wrap-UiAction -Name "update" -Action { Do-Update }) )

$btnRunDeploy.Add_Click( (Wrap-UiAction -Name "run-deploy" -Action {
  $DeployScriptPath = $txtDeploy.Text
  Do-RunDeployScript
}))

$btnPS.Add_Click( (Wrap-UiAction -Name "ps-admin" -Action { Open-Terminal "ps-admin" }) )
$btnWSL.Add_Click( (Wrap-UiAction -Name "wsl" -Action { Open-Terminal "wsl" }) )
$btnWT.Add_Click( (Wrap-UiAction -Name "wt" -Action { Open-Terminal "wt" }) )

$btnDockerBash.Add_Click( (Wrap-UiAction -Name "docker-bash" -Action {
  $img = "networkarchetype-plm:latest"
  Open-DockerBash $img
}))

$btnHyperV.Add_Click( (Wrap-UiAction -Name "hyperv-manager" -Action { Do-OpenHyperVManager }) )
$btnHyperVNote.Add_Click( (Wrap-UiAction -Name "hyperv-note" -Action { Do-CreateHyperVSandboxNote }) )

$btnLaunchCLI.Add_Click( (Wrap-UiAction -Name "launch-cli" -Action {
  $startScript = Join-Path $script:RepoRoot "start_plm.ps1"
  if (-not (Test-Path $startScript)) { Log "start_plm.ps1 not found."; return }
  Start-Process powershell.exe -ArgumentList "-ExecutionPolicy","Bypass","-File",$startScript,"-CLI" | Out-Null
  Log "Launched CLI console from GUI."
  Append-ContextLog "switch:gui->cli"
}))

$cmbMode.Add_SelectedIndexChanged( (Wrap-UiAction -Name "mode-change" -Action {
  $mode = $cmbMode.SelectedItem.ToString()
  Log "Selected mode: $mode"
}))

$form.Add_Shown( (Wrap-UiAction -Name "form-shown" -Action {
  Set-AdvancedMode $false
  Log "PLM Environment Admin GUI started (Admin)."
  Log "Tip: Click Detect. If missing components, click Install/Repair. For updates, click Update."
  $s = Detect-Environment
  Render-Status $s
  Write-StoreEvent -Kind "env" -Message "gui:env-on-load" -Payload $s
  Check-Collision
}))

[void]$form.ShowDialog()
