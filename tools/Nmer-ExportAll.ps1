param(
    [string]$Root = "",
    [switch]$IncludeCache,
    [switch]$IncludeDataDb,
    [switch]$WhatIf
)

foreach ($rel in @("_Resolve.ps1", "ci\_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$diagDir = Join-Path $Root "Cache\diagnostics"
if (-not (Test-Path -LiteralPath $diagDir)) {
    New-Item -ItemType Directory -Path $diagDir -Force | Out-Null
}
$zipPath = Join-Path $diagDir "nmer_export_$stamp.zip"

$paths = @(
    @{ id = "local.config"; path = "local\CursorShortcut.ini"; sensitive = $false },
    @{ id = "local.prompt_templates"; path = "local\PromptTemplates.ini"; sensitive = $false },
    @{ id = "local.user_studio"; path = "local\user_studio.json"; sensitive = $true },
    @{ id = "local.user_studio_backup"; path = "local\user_studio.backup.json"; sensitive = $true },
    @{ id = "local.niuma_chat_llm"; path = "local\niuma_chat_llm.json"; sensitive = $true },
    @{ id = "local.openclaw_state"; path = "local\openclaw-state"; sensitive = $true },
    @{ id = "data.search.history"; path = "Data\search\SearchCenterHistory.json"; sensitive = $false },
    @{ id = "data.search.fulltext_settings"; path = "Data\search\fulltext_settings.json"; sensitive = $false },
    @{ id = "data.search.fulltext_config"; path = "Data\search\fulltext_config.json"; sensitive = $false },
    @{ id = "data.state.prompts"; path = "Data\state\prompts.json"; sensitive = $false },
    @{ id = "data.state.cmdpal"; path = "Data\state\CommandPaletteExec.json"; sensitive = $false },
    @{ id = "data.state.vk_keymap"; path = "Data\state\vk_cursor_keymap_compiled.json"; sensitive = $false },
    @{ id = "data.state.config"; path = "Data\state\config.json"; sensitive = $false }
)

if ($IncludeDataDb) {
    $paths += @(
        @{ id = "data.db.clipboard"; path = "Data\db\Clipboard.db"; sensitive = $false },
        @{ id = "data.db.clipboard_wal"; path = "Data\db\Clipboard.db-wal"; sensitive = $false },
        @{ id = "data.db.clipboard_shm"; path = "Data\db\Clipboard.db-shm"; sensitive = $false },
        @{ id = "data.db.cursor"; path = "Data\db\CursorData.db"; sensitive = $false }
    )
}

if ($IncludeCache) {
    $paths += @(
        @{ id = "cache.debug"; path = "Cache\debug"; sensitive = $false },
        @{ id = "cache.images"; path = "Cache\images"; sensitive = $false },
        @{ id = "cache.thumbs"; path = "Cache\thumbs"; sensitive = $false }
    )
}

$manifest = @{
    version = "1"
    exportedAt = (Get-Date).ToString("o")
    root = $Root
    includeCache = [bool]$IncludeCache
    includeDataDb = [bool]$IncludeDataDb
    secretsVaultIncluded = $false
    notExported = @(
        'local/secrets.vault.json: DPAPI vault, never included in zip'
        'HKCU/Run autostart: see Nmer-CleanUninstall.ps1'
        'Cache/fulltext-index: large; optional -IncludeCache'
        'Data/db/*.db: optional -IncludeDataDb'
        'Settings UI export pack: user_studio subset only'
    )
    files = @()
}

$tempDir = Join-Path $env:TEMP "nmer_export_$stamp"
if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

foreach ($item in $paths) {
    $abs = Join-Path $Root $item.path
    $relOut = $item.path -replace '\\', '/'
    $entry = @{
        id = $item.id
        path = $relOut
        exists = $false
        sensitiveFieldNames = $(if ($item.sensitive) { @("apiKey", "apiKeys", "llmApiKeys", "options.llmApiKeys") } else { @() })
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

$manifestJson = $manifest | ConvertTo-Json -Depth 6
Set-Content -LiteralPath (Join-Path $tempDir "manifest.json") -Value $manifestJson -Encoding UTF8

Write-Output "== Nmer ExportAll =="
Write-Output "root=$Root"
Write-Output "zip=$zipPath"
Write-Output "includeDataDb=$IncludeDataDb"
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
