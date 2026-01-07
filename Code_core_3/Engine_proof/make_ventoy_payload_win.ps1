# make_ventoy_payload_win.ps1
# Generates Ventoy payload for:
#  - Windows 11 Pro (unattend)
#  - Windows Server 2025 (unattend)
#  - Ubuntu Server 24.04 (cloud-init autoinstall)
#  - Ubuntu Desktop 24.04 (cloud-init autoinstall - best effort)
#
# Ventoy behavior:
#  - autosel=0 => boot without template (guided)
#  - autosel=1 => boot with template #1 (automated)
#  - timeout=0 => prompt menu always shown (no timeout)
#
# Ventoy docs: AutoInstall plugin + autosel/timeout + variables expansion
# Built-in disk var: $$VT_WINDOWS_DISK_1ST_NONVTOY$$ (avoid installing to Ventoy USB)
# :contentReference[oaicite:1]{index=1}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p | Out-Null } }
function Write-Utf8NoBom($path, $content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

Write-Host ""
Write-Host "=== Ventoy Payload Builder (Win11 Pro / Server 2025 / Ubuntu 24.04) ==="
Write-Host "Output is a folder you copy to Ventoy USB partition #1."
Write-Host ""

$rootDefault = Join-Path $PWD.Path "bak\VENTOY_PAYLOAD"
$root = Read-Host "Output folder [$rootDefault]"
if([string]::IsNullOrWhiteSpace($root)){ $root = $rootDefault }

# Always show guided vs automated menu:
# - autosel 0 so default is guided unless user chooses a template
# - timeout 0 so it waits for a choice every time
$menuMode = Read-Host "Menu mode: (1) Always prompt (recommended) or (2) Auto-run automated after 10s? [1]"
if([string]::IsNullOrWhiteSpace($menuMode)){ $menuMode = "1" }
$timeout = if($menuMode -eq "2"){ 10 } else { 0 }
$autoselDefault = if($menuMode -eq "2"){ 1 } else { 0 }

Ensure-Dir $root
Ensure-Dir (Join-Path $root "ISO\Windows11")
Ensure-Dir (Join-Path $root "ISO\WindowsServer2025")
Ensure-Dir (Join-Path $root "ISO\UbuntuServer2404")
Ensure-Dir (Join-Path $root "ISO\UbuntuDesktop2404")

Ensure-Dir (Join-Path $root "ventoy\script")
Ensure-Dir (Join-Path $root "ventoy\theme\icons")

# --- ventoy.json ---
# Using parent directory matching so ANY ISO in that directory gets the same templates. :contentReference[oaicite:2]{index=2}
$ventoyJson = @"
{
  "auto_install": [
    {
      "parent": "/ISO/Windows11",
      "template": [
        "/ventoy/script/win11_pro_autounattend.xml",
        "/ventoy/script/win11_pro_autounattend_alt.xml"
      ],
      "autosel": $autoselDefault,
      "timeout": $timeout
    },
    {
      "parent": "/ISO/WindowsServer2025",
      "template": [
        "/ventoy/script/ws2025_autounattend.xml",
        "/ventoy/script/ws2025_autounattend_alt.xml"
      ],
      "autosel": $autoselDefault,
      "timeout": $timeout
    },
    {
      "parent": "/ISO/UbuntuServer2404",
      "template": [
        "/ventoy/script/ubuntu_server_2404_user-data",
        "/ventoy/script/ubuntu_server_2404_user-data_alt"
      ],
      "autosel": $autoselDefault,
      "timeout": $timeout
    },
    {
      "parent": "/ISO/UbuntuDesktop2404",
      "template": [
        "/ventoy/script/ubuntu_desktop_2404_user-data",
        "/ventoy/script/ubuntu_desktop_2404_user-data_alt"
      ],
      "autosel": $autoselDefault,
      "timeout": $timeout
    }
  ],
  "menu_class": [
    { "key": "Windows", "class": "windows" },
    { "key": "Server", "class": "windows" },
    { "key": "ubuntu", "class": "ubuntu" }
  ]
}
"@
Write-Utf8NoBom (Join-Path $root "ventoy\ventoy.json") $ventoyJson

# --- Windows 11 Pro unattend (Template #1) ---
# IMPORTANT: This is a safe, “whole-disk wipe + install” baseline.
# Uses Ventoy built-in disk variable to avoid selecting the Ventoy USB. :contentReference[oaicite:3]{index=3}
$win11 = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">

  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage><UserLocale>en-US</UserLocale>
    </component>

    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>$$VT_WINDOWS_DISK_1ST_NONVTOY$$</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>260</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>

      <ImageInstall>
        <OSImage>
          <InstallTo><DiskID>$$VT_WINDOWS_DISK_1ST_NONVTOY$$</DiskID><PartitionID>3</PartitionID></InstallTo>
        </OSImage>
      </ImageInstall>

      <UserData>
        <AcceptEula>true</AcceptEula>
      </UserData>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>

      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Bootstrap PLM + Cirq</Description>
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "try { if(Get-Command winget -ea 0){ winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements ; winget install --id Python.Python.3.11 -e --source winget --accept-package-agreements --accept-source-agreements ; mkdir C:\PLM -Force | Out-Null ; git clone https://github.com/NetworkArchetype/PLM C:\PLM\PLM ; python -m pip install --upgrade pip ; python -m pip install cirq ; python -c \"import cirq; print(cirq.__version__)\" } } catch {}"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"@
Write-Utf8NoBom (Join-Path $root "ventoy\script\win11_pro_autounattend.xml") $win11

# --- Windows 11 Pro unattend ALT (Template #2) ---
# Alternative: same install, but NO disk wipe (lets you guide disk selection manually).
$win11Alt = $win11 `
  -replace "<WillWipeDisk>true</WillWipeDisk>", "<WillWipeDisk>false</WillWipeDisk>" `
  -replace "<DiskConfiguration>[\s\S]*?</DiskConfiguration>", "<DiskConfiguration></DiskConfiguration>"
Write-Utf8NoBom (Join-Path $root "ventoy\script\win11_pro_autounattend_alt.xml") $win11Alt

# --- Windows Server 2025 unattend (Template #1) ---
# Same model: wipe disk + install + post-install bootstrap.
# Answer-file mechanics are the same family; you’ll still likely want to generate/verify via WADK for production. :contentReference[oaicite:4]{index=4}
$ws2025 = $win11 `
  -replace "Windows</Label>", "WindowsServer</Label>" `
  -replace "Bootstrap PLM \+ Cirq", "Bootstrap PLM + Cirq (Server 2025)"
Write-Utf8NoBom (Join-Path $root "ventoy\script\ws2025_autounattend.xml") $ws2025

$ws2025Alt = $win11Alt `
  -replace "Bootstrap PLM \+ Cirq", "Bootstrap PLM + Cirq (Server 2025 ALT)"
Write-Utf8NoBom (Join-Path $root "ventoy\script\ws2025_autounattend_alt.xml") $ws2025Alt

# --- Ubuntu Server 24.04 autoinstall (Template #1) ---
# Ventoy supports Ubuntu Server 20.x+ cloud-init user-data templates. :contentReference[oaicite:5]{index=5}
# This script will PROMPT you for a password hash at runtime; no password is stored in this repo.
function Read-RequiredUbuntuPasswordHash {
  while ($true) {
    $h = Read-Host "Enter Ubuntu autoinstall password hash (SHA-512 crypt; starts with $6$)"
    if ([string]::IsNullOrWhiteSpace($h)) {
      throw "Password hash is required. Re-run and provide a SHA-512 crypt hash (starts with $6$)."
    }
    if ($h -notmatch '^\$6\$') {
      Write-Warning "Expected a SHA-512 crypt hash starting with $6$. Try again."
      continue
    }
    return $h
  }
}

$ubuntuPasswordHash = Read-RequiredUbuntuPasswordHash

$ubServerTemplate = @'
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard: { layout: us }
  identity:
    hostname: plm-ubuntu-server
    username: plm
    # NOTE: This output file will contain the password hash; treat it as sensitive and do not commit it.
    password: "__PLM_PASSWORD_HASH__"
  ssh:
    install-server: true
    allow-pw: true

  storage:
    layout:
      name: direct

  packages: [git, python3, python3-pip]

  late-commands:
    - curtin in-target --target=/target -- bash -lc 'mkdir -p /opt/plm && git clone https://github.com/NetworkArchetype/PLM /opt/plm/PLM'
    - curtin in-target --target=/target -- bash -lc 'python3 -m pip install --upgrade pip && python3 -m pip install cirq'
    - curtin in-target --target=/target -- bash -lc 'python3 -c "import cirq; print(cirq.__version__)" > /root/cirq_version.txt'
'@
$ubServer = $ubServerTemplate -replace '__PLM_PASSWORD_HASH__', $ubuntuPasswordHash
Write-Utf8NoBom (Join-Path $root "ventoy\script\ubuntu_server_2404_user-data") $ubServer

# Ubuntu Server ALT: keep guided storage (no wipe) but still installs packages & PLM post-setup
$ubServerAlt = $ubServer -replace "storage:\s*[\s\S]*?packages:", "packages:"
Write-Utf8NoBom (Join-Path $root "ventoy\script\ubuntu_server_2404_user-data_alt") $ubServerAlt

# --- Ubuntu Desktop 24.04 autoinstall (Template #1) ---
# Desktop automation is less uniform; Subiquity-based approaches exist for 24.04 Desktop as well. :contentReference[oaicite:6]{index=6}
# Treat this as “best effort” and test in a VM first.
$ubDesktop = $ubServer `
  -replace "plm-ubuntu-server", "plm-ubuntu-desktop" `
  -replace "install-server: true", "install-server: false"
Write-Utf8NoBom (Join-Path $root "ventoy\script\ubuntu_desktop_2404_user-data") $ubDesktop

$ubDesktopAlt = $ubServerAlt `
  -replace "plm-ubuntu-server", "plm-ubuntu-desktop" `
  -replace "install-server: true", "install-server: false"
Write-Utf8NoBom (Join-Path $root "ventoy\script\ubuntu_desktop_2404_user-data_alt") $ubDesktopAlt

# Icons optional; Ventoy will still work without them.
Set-Content -Path (Join-Path $root "ventoy\theme\icons\windows.png") -Value "REPLACE_WITH_PNG" -Encoding ascii
Set-Content -Path (Join-Path $root "ventoy\theme\icons\ubuntu.png") -Value "REPLACE_WITH_PNG" -Encoding ascii

Write-Host ""
Write-Host "DONE ✅ Payload created at:"
Write-Host "  $root"
Write-Host ""
Write-Host "Place your ISOs (official, unchanged) into these folders:"
Write-Host "  $root\ISO\Windows11\                 (any Win11 ISO name)"
Write-Host "  $root\ISO\WindowsServer2025\         (any Server 2025 ISO name)"
Write-Host "  $root\ISO\UbuntuServer2404\          (ubuntu server ISO)"
Write-Host "  $root\ISO\UbuntuDesktop2404\         (ubuntu desktop ISO)"
Write-Host ""
Write-Host "Then copy the CONTENTS of $root to the FIRST partition of your Ventoy USB."
Write-Host "At boot, Ventoy will show the Auto-Install prompt:"
Write-Host "  0 = Guided (no template) | 1 = Automated template #1 | 2 = Automated template #2"
Write-Host ""

