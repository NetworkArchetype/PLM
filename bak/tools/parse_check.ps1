[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]]$Paths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$hadErrors = $false
foreach ($p in $Paths) {
  $full = Resolve-Path -LiteralPath $p -ErrorAction Stop
  $lines = Get-Content -LiteralPath $full.Path
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($full.Path, [ref]$tokens, [ref]$errors)

  if ($errors -and $errors.Count -gt 0) {
    $hadErrors = $true
    Write-Host "PARSE_FAIL: $p ($($errors.Count) errors)"
    foreach ($e in $errors) {
      if ($e.Extent) {
        $line = $e.Extent.StartLineNumber
        $col = $e.Extent.StartColumnNumber
        if ($line -ne $null -and $col -ne $null) {
          Write-Host (" - L$line:C$col " + $e.Message)
        } elseif ($line -ne $null) {
          Write-Host (" - L$line " + $e.Message)
        } else {
          Write-Host (" - " + $e.Message)
        }

        if ($line -and $line -ge 1 -and $line -le $lines.Count) {
          $src = $lines[$line - 1]
          Write-Host ("   > " + $src)
        }
      } else {
        Write-Host (" - " + $e.Message)
      }
    }
  } else {
    Write-Host "PARSE_OK: $p"
  }
}

if ($hadErrors) { exit 1 }
