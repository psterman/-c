param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [string]$Root = "",
    [string]$OutJson = ""
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

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tempDir = Join-Path $env:TEMP "nmer_preview_$stamp"
if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $tempDir)

$manifestPath = Join-Path $tempDir "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "manifest.json missing in zip"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$catalog = Get-NmerMigrationGroupCatalog -Root $Root
$byId = @{}
foreach ($g in $catalog) { $byId[$g.id] = $g }

$groupSummary = @()
$manifestGroups = @()
if ($manifest.groups) { $manifestGroups = @($manifest.groups | ForEach-Object { [string]$_ }) }

if ($manifestGroups.Count -gt 0) {
    foreach ($gid in $manifestGroups) {
        if (-not $byId.ContainsKey($gid)) { continue }
        $g = $byId[$gid]
        $fileCount = 0
        foreach ($fe in $manifest.files) {
            if (-not $fe.exists) { continue }
            foreach ($e in $g.entries) {
                if ([string]$fe.id -eq [string]$e.id) { $fileCount++; break }
            }
        }
        $groupSummary += @{
            id = $gid
            label = $g.label
            hint = $g.hint
            fileCount = $fileCount
        }
    }
} else {
    foreach ($fe in $manifest.files) {
        if ($fe.exists) { $groupSummary += @{ id = [string]$fe.id; label = [string]$fe.path; hint = ""; fileCount = 1 } }
    }
}

$existingFiles = @($manifest.files | Where-Object { $_.exists })
$out = @{
    ok = $true
    zip = $ZipPath
    version = [string]$manifest.version
    kind = [string]$manifest.kind
    exportedAt = [string]$manifest.exportedAt
    preset = [string]$manifest.preset
    groups = $groupSummary
    fileCount = $existingFiles.Count
    postImportNote = [string]$manifest.postImportNote
}

Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
$json = $out | ConvertTo-Json -Depth 8
if ($OutJson) {
    Set-Content -LiteralPath $OutJson -Value $json -Encoding UTF8
} else {
    Write-Output $json
}
