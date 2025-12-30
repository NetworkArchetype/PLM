# scripts\upload_random_artifact.ps1
# PowerShell equivalent of the bash uploader.
param(
  [string]$Tarball = "bak/20251230-030000/plm-ci-debug-20251230-030000.tar.gz",
  [int]$Prob = 10,
  [switch]$DryRun,
  [string]$UploadUrl,
  [string]$UploadToken,
  [string]$ReleaseTag
)

Write-Output "Random threshold: $Prob"
$rand = Get-Random -Maximum 100
Write-Output "Random value: $rand"
if ($rand -ge $Prob) {
  Write-Output "Skipping upload (random threshold not met)."; exit 0
}
if ($DryRun) { Write-Output "DRY RUN: would upload $Tarball"; exit 0 }

if ($UploadUrl) {
  if (-not $UploadToken) { Write-Error "UploadToken required for UploadUrl"; exit 1 }
  Write-Output "Uploading $Tarball to $UploadUrl"
  try {
    $form = @{ file = Get-Item $Tarball }
    Invoke-RestMethod -Uri $UploadUrl -Method Post -Headers @{ Authorization = "Bearer $UploadToken" } -Form $form
    Write-Output "Upload complete."
  } catch {
    Write-Error "Upload failed: $_"; exit 1
  }
  exit 0
}

if ($ReleaseTag) {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Error "gh CLI required to upload to GitHub release"; exit 1 }
  Write-Output "Uploading $Tarball to GitHub release $ReleaseTag"
  & gh release upload $ReleaseTag $Tarball
  if ($LASTEXITCODE -ne 0) { Write-Error "gh upload failed"; exit 1 }
  Write-Output "Upload to release complete."
  exit 0
}

Write-Error "No upload configured (provide UploadUrl+UploadToken or ReleaseTag)."; exit 2
