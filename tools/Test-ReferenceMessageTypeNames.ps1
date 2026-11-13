<#
.SYNOPSIS
    Applies Foundation's three-part naming guard to each configured product sample.
.DESCRIPTION
    Guard copied unchanged from Foundation tools/Test-MessageTypeNames.ps1
    (Git blob a13388953833b005de19e542d45a6e2c1fa2f30b, issue #1037).
    Test folders are intentionally exempt. No allow-list or CI settings changes.
#>
param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$settings = Get-Content -LiteralPath (Join-Path $ProjectRoot '.AL-Go/settings.json') -Raw | ConvertFrom-Json
$folders = @($settings.appFolders)
if ($folders.Count -eq 0) { throw 'No product app folders configured; the guard checked nothing.' }
foreach ($folder in $folders) {
    Write-Host "Checking product app: $folder"
    & (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })) -NoProfile -File (Join-Path $PSScriptRoot 'Test-MessageTypeNames.ps1') -AppFolder (Join-Path $ProjectRoot $folder)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
