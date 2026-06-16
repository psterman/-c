param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$tools = Join-Path $Root "tools"
$manifest = Join-Path $tools "Nmer-MigrationManifest.ps1"
$export = Join-Path $tools "Nmer-ExportAll.ps1"

if (-not (Test-Path -LiteralPath $manifest)) {
    Write-Output "FAIL missing=Nmer-MigrationManifest.ps1"
    exit 1
}
if (-not (Test-Path -LiteralPath $export)) {
    Write-Output "FAIL missing=Nmer-ExportAll.ps1"
    exit 1
}

. $manifest
$entries = Get-NmerMigrationEntries -Root $Root -Preset recommended
if ($entries.Count -lt 15) {
    Write-Output "FAIL entries=$($entries.Count)"
    exit 1
}
$catalog = Get-NmerMigrationGroupCatalog -Root $Root
if ($catalog.Count -lt 13) {
    Write-Output "FAIL catalog=$($catalog.Count)"
    exit 1
}

& $export -Root $Root -WhatIf 2>&1 | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Output "FAIL export_whatif exit=$LASTEXITCODE"
    exit 1
}

Write-Output "PASS migration_manifest_entries=$($entries.Count)"
exit 0
