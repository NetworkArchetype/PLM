# make_ventoy_payload.ps1
# Generates a Ventoy payload folder with:
# - ventoy.json (Auto Install + Menu Class icons)
# - Windows autounattend.xml template (placeholder-safe)
# - Ubuntu Server cloud-init (user-data/meta-data)
# - Optional download of Ubuntu ISO
#
# After generation:
# 1) Install Ventoy to a USB using Ventoy2Disk.exe (Ventoy docs). 
# 2) Copy the CONTENTS of VENTOY_PAYLOAD/ to the FIRST partition of the Ventoy USB:
#    - ISO/...
#    - ventoy/ventoy.json + ventoy/script/*
#
# Ventoy plugin entrypoint requires /ventoy/ventoy.json at root of 1st partition. (Ventoy docs)
# Auto-install plugin supports autosel=0 to boot without template (guided) and autosel>=1 to auto-pick template. (Ventoy docs)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Prompt-Path([string]$label, [string]$default) {
  $v = Read-Host "$label [$default]"
  if ([string]::IsNullOrWhiteSpace($v)) { return $default }
  return $v
}

function Ensure-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

function Write-FileUtf8NoBom($path, $content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

Write-Host ""
Write-Host "=== Ventoy Payload Generator (Windows + Ubuntu) ==="
Write-Host "This creates a Ventoy-ready folder tree with auto-install templates + ventoy.json."
Write-Host ""

$root = Prompt-Path "Output directory to create VENTOY_PAYLOAD" (Join-Path $PWD.Path "VENTOY_PAYLOAD")
$downloadUbuntu = (Read-Host "Download Ubuntu Server ISO automatically? (y/n) [n]").Trim().ToLower()
if ($downloadUbuntu -ne "y") { $downloadUbuntu = "n" }

Ensure-Dir $root
Ensure-Dir (Join-Path $root "ISO\Windows")
Ensure-Dir (Join-Path $root "ISO\Ubuntu")
Ensure-Dir (Join-Path $root "ventoy\script")
Ensure-Dir (Join-Path $root "ventoy\theme\icons")

# --------------------------
# 1) ventoy.json
# --------------------------
# We configure two behaviors by using autosel + timeout:
# - Windows: show a prompt (timeout>0). Default = unattended (autosel=1). User can choose "0 boot without template".
# - Ubuntu: same.
#
# IMPORTANT: You must rename your ISOs to match keys below (or edit this file to match your ISO names).
# Ventoy supports full path matching and fuzzy matching (see Ventoy docs).
$ventoyJson = @"
{
  "auto_install": [
    {
      "image": "/ISO/Windows/Windows_11.iso",
      "template": [
        "/ventoy/script/windows_autounattend.xml"
      ],
      "autosel": 1,
      "timeout": 15
    },
    {
      "image": "/ISO/Ubuntu/ubuntu-server.iso",
      "template": [
        "/ventoy/script/ubuntu_user-data"
      ],
      "autosel": 1,
      "timeout": 15
    }
  ],
  "menu_class": [
    { "key": "Windows", "class": "windows" },
    { "key": "ubuntu",   "class": "ubuntu" }
  ]
}
"@

Write-FileUtf8NoBom (Join-Path $root "ventoy\ventoy.json") $ventoyJson

# --------------------------
# 2) Windows autounattend.xml (template)
# --------------------------
# This is a minimal-ish skeleton focusing on automation hooks.
# You MUST customize:
# - Locale, edition selection, product key policy, partitioning.
# Ventoy variables expansion can help choose the correct disk (see VT_WINDOWS_* variables in Ventoy docs).
#
# NOTE: Ventoy auto install uses autounattend.xml (not unattend.xml) in WinPE context.
$winXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <!--
    Ventoy Auto Install Template for Windows.
    You MUST customize this for your licensing/edition and disk layout.

    Tip (Ventoy Variables Expansion):
      Use $$VT_WINDOWS_DISK_1ST_NONVTOY$$ to avoid installing onto the Ventoy USB disk.
      (Ventoy docs list VT_WINDOWS_* variables and behavior.)
  -->

  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <!-- Disk configuration (PLACEHOLDER) -->
      <!-- WARNING: This is intentionally conservative. Customize partitioning for your environment. -->
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>$$VT_WINDOWS_DISK_1ST_NONVTOY$$</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>EFI</Type>
              <Size>260</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Type>MSR</Type>
              <Size>16</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <Format>FAT32</Format>
              <Label>System</Label>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Order>2</Order>
              <PartitionID>3</PartitionID>
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Letter>C</Letter>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>

      <!-- Image selection (PLACEHOLDER) -->
      <ImageInstall>
        <OSImage>
          <InstallTo>
            <DiskID>$$VT_WINDOWS_DISK_1ST_NONVTOY$$</DiskID>
            <PartitionID>3</PartitionID>
          </InstallTo>
          <!-- You may need InstallFrom/MetaData depending on ISO -->
        </OSImage>
      </ImageInstall>

      <UserData>
        <AcceptEula>true</AcceptEula>
        <!-- ProductKey is optional depending on media and activation plan -->
      </UserData>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
      publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>

      <!-- Post-install hook: install git/python and clone PLM + install cirq -->
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Install Git + Python, clone PLM, install Cirq</Description>
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "try { if(-not (Get-Command winget -ea 0)) { exit 0 } ; winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements ; winget install --id Python.Python.3.11 -e --source winget --accept-package-agreements --accept-source-agreements ; mkdir C:\PLM | Out-Null ; git clone https://github.com/NetworkArchetype/PLM C:\PLM\PLM ; python -m pip install --upgrade pip ; python -m pip install cirq ; python -c \"import cirq; print(cirq.__version__)\" } catch { exit 0 }"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>

    </component>
  </settings>
</unattend>
"@

# add namespace needed by some unattend schemas
$winXml = $winXml -replace "<unattend ", "<unattend xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`" "
Write-FileUtf8NoBom (Join-Path $root "ventoy\script\windows_autounattend.xml") $winXml

# --------------------------
# 3) Ubuntu Server cloud-init (user-data/meta-data)
# --------------------------
# Ventoy supports Ubuntu Server 20.x+ cloud-init via Auto Install plugin. (Ventoy docs)
# Ubuntu autoinstall is cloud-init based. (Ubuntu docs)
# You MUST customize identity/password, storage layout, etc.
$ubuntuUserData = @"
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  identity:
    hostname: plm-ubuntu
    username: plm
    # Password is "plm" hashed example (CHANGE THIS).
    # Generate with: python3 -c "import crypt; print(crypt.crypt('plm', crypt.mksalt(crypt.METHOD_SHA512)))"
    password: "\$6\$CHANGE_ME\$CHANGE_ME_TOO"
  ssh:
    install-server: true
    allow-pw: true

  storage:
    layout:
      name: direct

  packages:
    - git
    - python3
    - python3-pip

  late-commands:
    - curtin in-target --target=/target -- bash -lc 'mkdir -p /opt/plm && git clone https://github.com/NetworkArchetype/PLM /opt/plm/PLM'
    - curtin in-target --target=/target -- bash -lc 'python3 -m pip install --upgrade pip && python3 -m pip install cirq'
    - curtin in-target --target=/target -- bash -lc 'python3 -c "import cirq; print(cirq.__version__)" > /root/cirq_version.txt'
"@
Write-FileUtf8NoBom (Join-Path $root "ventoy\script\ubuntu_user-data") $ubuntuUserData

$ubuntuMeta = @"
instance-id: plm-ubuntu
local-hostname: plm-ubuntu
"@
Write-FileUtf8NoBom (Join-Path $root "ventoy\script\ubuntu_meta-data") $ubuntuMeta

# --------------------------
# 4) Optional icons (placeholders)
# --------------------------
# Menu Class plugin shows icons by class name. (Ventoy docs)
# If you want real icons, replace these PNGs later.
# We'll just create tiny placeholder files to remind you.
Set-Content -Path (Join-Path $root "ventoy\theme\icons\windows.png") -Value "REPLACE_WITH_PNG" -Encoding ascii
Set-Content -Path (Join-Path $root "ventoy\theme\icons\ubuntu.png")   -Value "REPLACE_WITH_PNG" -Encoding ascii

# --------------------------
# 5) Optional Ubuntu ISO download
# --------------------------
if ($downloadUbuntu -eq "y") {
  Write-Host ""
  Write-Host "Ubuntu ISO download is optional and depends on which release you want."
  Write-Host "For licensing/terms, Windows ISO is NOT downloaded by this script."
  Write-Host ""
  $ubuntuUrl = Read-Host "Paste direct URL to Ubuntu Server ISO (e.g. from releases.ubuntu.com)"
  if (-not [string]::IsNullOrWhiteSpace($ubuntuUrl)) {
    $destIso = Join-Path $root "ISO\Ubuntu\ubuntu-server.iso"
    Write-Host "Downloading -> $destIso"
    Invoke-WebRequest -Uri $ubuntuUrl -OutFile $destIso
  }
}

Write-Host ""
Write-Host "DONE."
Write-Host "Payload created at: $root"
Write-Host ""
Write-Host "NEXT:"
Write-Host "  1) Install Ventoy onto a USB drive."
Write-Host "  2) Copy the contents of $root to the FIRST partition of the Ventoy USB."
Write-Host "  3) Put your official Windows ISO at: ISO\Windows\Windows_11.iso"
Write-Host "  4) Boot the USB. Ventoy will prompt: unattended (template) or guided (no template)."
Write-Host ""
