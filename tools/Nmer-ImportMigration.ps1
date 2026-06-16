param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [string]$Root = "",
    [switch]$WhatIf,
    [switch]$Force
)

foreach ($rel in @("_Resolve.ps1", "ci\_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
. (Join-Path $PSScriptRoot "Nmer-MigrationManifest.ps1")
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ZipPath)) {
    Write-Error "Zip not found: $ZipPath"
}

function Test-NmerProcessRunning {
    $names = @("AutoHotkey64", "AutoHotkey32", "AutoHotkey")
    foreach ($n in $names) {
        if (Get-Process -Name $n -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

if ((Test-NmerProcessRunning) -and -not $Force -and -not $WhatIf) {
    Write-Error "AutoHotkey is running. Exit Nmer before import, or pass -Force (may corrupt open databases)."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tempDir = Join-Path $env:TEMP "nmer_import_$stamp"
if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempDir -Force

$manifestPath = Join-Path $tempDir "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "manifest.json missing in zip"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$kind = [string]$manifest.kind
$version = [string]$manifest.version
if ($kind -ne "migration") {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "Invalid pack kind: $kind (expected migration)"
}
if ([int]$version -lt 2) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "Unsupported manifest version: $version (need >= 2)"
}

$backupRoot = Join-Path $Root ("local\backup-migration-$stamp")
$result = @{
    version = "1"
    importedAt = (Get-Date).ToString("o")
    zip = $ZipPath
    root = $Root
    backupRoot = $backupRoot
    whatIf = [bool]$WhatIf
    applied = @()
    skipped = @()
    failed = @()
    postImportNote = [string]$manifest.postImportNote
}

$vaultRel = "local/secrets.vault.json"

foreach ($fileEntry in $manifest.files) {
    if (-not $fileEntry.exists) { continue }
    $rel = ([string]$fileEntry.path) -replace '/', '\'
    if ($rel -eq "local\secrets.vault.json" -or $rel -eq $vaultRel) {
        $result.skipped += @{ path = $rel; reason = "secrets vault never imported" }
        continue
    }

    $src = Join-Path $tempDir $rel
    if (-not (Test-Path -LiteralPath $src)) {
        $result.skipped += @{ path = $rel; reason = "missing in extracted zip" }
        continue
    }

    $item = @{ id = [string]$fileEntry.id; path = $rel }
    if ($rel -match '^Cache\\') {
        $cacheRoot = Get-NmerUserCacheRoot -Root $Root
        $leaf = Split-Path -Leaf $rel
        $item.srcPath = Join-Path $cacheRoot $leaf
    }
    $dest = Resolve-NmerMigrationDestPath -Root $Root -Item $item

    try {
        if ($WhatIf) {
            $result.applied += @{ path = $rel; dest = $dest; whatIf = $true }
            continue
        }

        if (Test-Path -LiteralPath $dest) {
            $backupDest = Join-Path $backupRoot $rel
            $backupParent = Split-Path -Parent $backupDest
            if (-not (Test-Path -LiteralPath $backupParent)) {
                New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
            }
            if ((Get-Item -LiteralPath $dest).PSIsContainer) {
                if (Test-Path -LiteralPath $backupDest) {
                    Remove-Item -LiteralPath $backupDest -Recurse -Force
                }
                Copy-Item -LiteralPath $dest -Destination $backupDest -Recurse -Force
            } else {
                Copy-Item -LiteralPath $dest -Destination $backupDest -Force
            }
        }

        $destParent = Split-Path -Parent $dest
        if ($destParent -and -not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        if ((Get-Item -LiteralPath $src).PSIsContainer) {
            if (Test-Path -LiteralPath $dest) {
                Remove-Item -LiteralPath $dest -Recurse -Force
            }
            Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
        } else {
            Copy-Item -LiteralPath $src -Destination $dest -Force
        }
        $result.applied += @{ path = $rel; dest = $dest }
    } catch {
        $result.failed += @{ path = $rel; error = $_.Exception.Message }
    }
}

$resultPath = Join-Path $Root "Cache\diagnostics\import_result_$stamp.json"
if (-not $WhatIf) {
    $diagDir = Split-Path -Parent $resultPath
    if (-not (Test-Path -LiteralPath $diagDir)) {
        New-Item -ItemType Directory -Path $diagDir -Force | Out-Null
    }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "== Nmer Migration Import =="
Write-Output "root=$Root"
Write-Output "zip=$ZipPath"
Write-Output "whatIf=$WhatIf"
Write-Output "applied=$($result.applied.Count)"
Write-Output "skipped=$($result.skipped.Count)"
Write-Output "failed=$($result.failed.Count)"
if (-not $WhatIf) { Write-Output "result=$resultPath" }
if ($result.failed.Count -gt 0) {
    Write-Output "RESULT=FAIL"
    exit 1
}
Write-Output "RESULT=OK"
exit 0
