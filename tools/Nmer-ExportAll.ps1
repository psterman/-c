param(
    [string]$Root = "",
    [switch]$IncludeCache,
    [switch]$IncludeMediaCache,
    [bool]$IncludeDataDb = $true,
    [string]$Preset = "recommended",
    [string[]]$Groups = @(),
    [string]$OptionsJson = "",
    [string]$OutZip = "",
    [switch]$WhatIf
)

foreach ($rel in @("_Resolve.ps1", "ci\_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
. (Join-Path $PSScriptRoot "Nmer-MigrationManifest.ps1")
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

if ($OptionsJson -and (Test-Path -LiteralPath $OptionsJson)) {
    $opt = Get-Content -LiteralPath $OptionsJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($opt.preset) { $Preset = [string]$opt.preset }
    if ($opt.groups) { $Groups = @($opt.groups | ForEach-Object { [string]$_ }) }
}

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$diagDir = Join-Path $Root "Cache\diagnostics"
if (-not (Test-Path -LiteralPath $diagDir)) {
    New-Item -ItemType Directory -Path $diagDir -Force | Out-Null
}
if ($OutZip) {
    $zipPath = $OutZip
} else {
    $zipPath = Join-Path $diagDir "nmer_migration_$stamp.zip"
}

$includeMedia = [bool]$IncludeMediaCache
$includeDebug = [bool]$IncludeCache
if ($IncludeCache -and -not $IncludeMediaCache -and (-not $Groups -or $Groups.Count -eq 0)) {
    $includeMedia = $true
}

$resolvedGroups = Resolve-NmerMigrationGroups -Root $Root -Preset $Preset -Groups $Groups `
    -IncludeDataDb $IncludeDataDb -IncludeMediaCache $includeMedia -IncludeCacheDebug $includeDebug

$paths = Get-NmerMigrationEntries -Root $Root -Groups $resolvedGroups

$manifest = @{
    version = "2"
    kind = "migration"
    exportedAt = (Get-Date).ToString("o")
    root = $Root
    preset = $Preset
    groups = $resolvedGroups
    includeDataDb = [bool]$IncludeDataDb
    includeMediaCache = $includeMedia
    includeCacheDebug = $includeDebug
    secretsVaultIncluded = $false
    postImportNote = "请在智能定制中重新填写 API Key（secrets.vault.json 不随迁移包导出）"
    notExported = @(
        'local/secrets.vault.json: DPAPI vault, never included in zip'
        'HKCU/Run autostart: see Nmer-CleanUninstall.ps1'
        'Data/dict/*.db: repo-shipped dictionaries'
        'Customization pack: user_studio.json only via settings customize tab'
    )
    files = @()
}

$tempDir = Join-Path $env:TEMP "nmer_migration_$stamp"
if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$sensitiveFields = Get-NmerMigrationSensitiveFieldNames

foreach ($item in $paths) {
    $abs = Resolve-NmerMigrationSourcePath -Root $Root -Item $item
    $relOut = $item.path -replace '\\', '/'
    $entry = @{
        id = $item.id
        path = $relOut
        exists = $false
        sensitiveFieldNames = $(if ($item.sensitive) { $sensitiveFields } else { @() })
    }
    if (Test-Path -LiteralPath $abs) {
        $entry.exists = $true
        $dest = Join-Path $tempDir $item.path
        $destParent = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
        if ((Get-Item -LiteralPath $abs).PSIsContainer) {
            Copy-Item -LiteralPath $abs -Destination $dest -Recurse -Force
        } else {
            Copy-Item -LiteralPath $abs -Destination $dest -Force
        }
    }
    $manifest.files += $entry
}

$vault = Join-Path $Root "local\secrets.vault.json"
$manifest.secretsVaultExists = Test-Path -LiteralPath $vault

$manifestJson = $manifest | ConvertTo-Json -Depth 8
Set-Content -LiteralPath (Join-Path $tempDir "manifest.json") -Value $manifestJson -Encoding UTF8

Write-Output "== Nmer Migration Export =="
Write-Output "root=$Root"
Write-Output "zip=$zipPath"
Write-Output "preset=$Preset"
Write-Output "groups=$($resolvedGroups -join ',')"
Write-Output "docs=docs/nmer-paths-inventory.md"

if ($WhatIf) {
    Write-Output "WHATIF: skip zip"
    Remove-Item -LiteralPath $tempDir -Recurse -Force
    exit 0
}

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
$toZip = Get-ChildItem -LiteralPath $tempDir -Force
Compress-Archive -LiteralPath ($toZip | ForEach-Object { $_.FullName }) -DestinationPath $zipPath -Force
Remove-Item -LiteralPath $tempDir -Recurse -Force
Write-Output "RESULT=OK"
Write-Output "ZIP=$zipPath"
