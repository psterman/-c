# Migration manifest — sync with modules/LocalPaths.ahk (UI labels are Chinese in AHK)
# docs/nmer-paths-inventory.md

function Get-NmerUserCacheRoot {
    param([string]$Root)
    $ini = Join-Path $Root "local\CursorShortcut.ini"
    if (Test-Path -LiteralPath $ini) {
        $custom = ""
        foreach ($line in Get-Content -LiteralPath $ini -Encoding UTF8 -ErrorAction SilentlyContinue) {
            if ($line -match '^\s*UserCacheRoot\s*=\s*(.+)$') {
                $custom = $Matches[1].Trim()
                break
            }
        }
        if ($custom -ne "") { return $custom }
    }
    return Join-Path $Root "Cache"
}

function Get-NmerMigrationPresets {
    $recommended = @(
        'local.config', 'local.studio', 'local.openclaw', 'local.prompts',
        'data.search', 'data.state',
        'data.db.clipboard', 'data.db.cursor', 'data.runtime.chat'
    )
    $light = @(
        'local.config', 'local.studio', 'local.openclaw', 'local.prompts',
        'data.search', 'data.state'
    )
    $full = $recommended + @('cache.images', 'cache.thumbs', 'cache.temp')
    return @{
        recommended = $recommended
        light = $light
        full = $full
    }
}

function Get-NmerMigrationGroupCatalog {
    param([string]$Root = "")
    $cacheRoot = ""
    if ($Root) { $cacheRoot = Get-NmerUserCacheRoot -Root $Root }
    return @(
        @{
            id = 'local.config'; category = 'local'; label = 'Main config (INI)'; hint = 'CursorShortcut.ini'; default = $true
            entries = @(@{ id = 'local.config'; path = 'local\CursorShortcut.ini'; sensitive = $false })
        },
        @{
            id = 'local.studio'; category = 'local'; label = 'User studio'; hint = 'user_studio.json and related'; default = $true
            entries = @(
                @{ id = 'local.user_studio'; path = 'local\user_studio.json'; sensitive = $true },
                @{ id = 'local.user_studio_backup'; path = 'local\user_studio.backup.json'; sensitive = $true },
                @{ id = 'local.niuma_chat_llm'; path = 'local\niuma_chat_llm.json'; sensitive = $true }
            )
        },
        @{
            id = 'local.openclaw'; category = 'local'; label = 'OpenClaw state'; hint = 'openclaw-state folder'; default = $true
            entries = @(@{ id = 'local.openclaw_state'; path = 'local\openclaw-state'; sensitive = $true })
        },
        @{
            id = 'local.prompts'; category = 'local'; label = 'Prompt templates'; hint = 'PromptTemplates.ini'; default = $true
            entries = @(@{ id = 'local.prompt_templates'; path = 'local\PromptTemplates.ini'; sensitive = $false })
        },
        @{
            id = 'data.search'; category = 'data'; label = 'Search config'; hint = 'SearchCenter and fulltext JSON'; default = $true
            entries = @(
                @{ id = 'data.search.history'; path = 'Data\search\SearchCenterHistory.json'; sensitive = $false },
                @{ id = 'data.search.fulltext_settings'; path = 'Data\search\fulltext_settings.json'; sensitive = $false },
                @{ id = 'data.search.fulltext_config'; path = 'Data\search\fulltext_config.json'; sensitive = $false }
            )
        },
        @{
            id = 'data.state'; category = 'data'; label = 'App state JSON'; hint = 'prompts, command palette, vk map'; default = $true
            entries = @(
                @{ id = 'data.state.prompts'; path = 'Data\state\prompts.json'; sensitive = $false },
                @{ id = 'data.state.cmdpal'; path = 'Data\state\CommandPaletteExec.json'; sensitive = $false },
                @{ id = 'data.state.vk_keymap'; path = 'Data\state\vk_cursor_keymap_compiled.json'; sensitive = $false },
                @{ id = 'data.state.config'; path = 'Data\state\config.json'; sensitive = $false }
            )
        },
        @{
            id = 'data.db.clipboard'; category = 'data'; label = 'Clipboard DB'; hint = 'Clipboard.db + WAL/SHM'; default = $true
            entries = @(
                @{ id = 'data.db.clipboard'; path = 'Data\db\Clipboard.db'; sensitive = $false },
                @{ id = 'data.db.clipboard_wal'; path = 'Data\db\Clipboard.db-wal'; sensitive = $false },
                @{ id = 'data.db.clipboard_shm'; path = 'Data\db\Clipboard.db-shm'; sensitive = $false }
            )
        },
        @{
            id = 'data.db.cursor'; category = 'data'; label = 'Cursor panel DB'; hint = 'CursorData.db'; default = $true
            entries = @(@{ id = 'data.db.cursor'; path = 'Data\db\CursorData.db'; sensitive = $false })
        },
        @{
            id = 'data.runtime.chat'; category = 'data'; label = 'Niuma Chat data'; hint = 'runtime/niuma-chat'; default = $true
            entries = @(@{ id = 'data.runtime.niuma_chat'; path = 'Data\runtime\niuma-chat'; sensitive = $true })
        },
        @{
            id = 'cache.images'; category = 'cache'; label = 'Clipboard images'; hint = 'Cache/images'; default = $false
            entries = @(@{ id = 'cache.images'; path = 'Cache\images'; srcPath = $(if ($cacheRoot) { Join-Path $cacheRoot 'images' }); sensitive = $false })
        },
        @{
            id = 'cache.thumbs'; category = 'cache'; label = 'Thumbnails'; hint = 'Cache/thumbs'; default = $false
            entries = @(@{ id = 'cache.thumbs'; path = 'Cache\thumbs'; srcPath = $(if ($cacheRoot) { Join-Path $cacheRoot 'thumbs' }); sensitive = $false })
        },
        @{
            id = 'cache.temp'; category = 'cache'; label = 'Temp screenshots'; hint = 'Cache/temp'; default = $false
            entries = @(@{ id = 'cache.temp'; path = 'Cache\temp'; srcPath = $(if ($cacheRoot) { Join-Path $cacheRoot 'temp' }); sensitive = $false })
        },
        @{
            id = 'cache.fulltext'; category = 'cache'; label = 'Fulltext index'; hint = 'large, rebuild on new PC'; default = $false
            entries = @(@{ id = 'cache.fulltext_index'; path = 'Cache\fulltext-index'; srcPath = $(if ($cacheRoot) { Join-Path $cacheRoot 'fulltext-index' }); sensitive = $false })
        },
        @{
            id = 'cache.debug'; category = 'cache'; label = 'Debug logs'; hint = 'usually skip for migration'; default = $false
            entries = @(@{ id = 'cache.debug'; path = 'Cache\debug'; srcPath = $(if ($cacheRoot) { Join-Path $cacheRoot 'debug' }); sensitive = $false })
        }
    )
}

function Resolve-NmerMigrationGroups {
    param(
        [string]$Root,
        [string]$Preset = 'recommended',
        [string[]]$Groups = @(),
        [bool]$IncludeDataDb = $true,
        [bool]$IncludeMediaCache = $false,
        [bool]$IncludeCacheDebug = $false
    )
    $presets = Get-NmerMigrationPresets
    if ($Groups -and $Groups.Count -gt 0) {
        return @($Groups | ForEach-Object { [string]$_ } | Where-Object { $_ })
    }
    if ($Preset -and $presets.ContainsKey($Preset)) {
        $resolved = @($presets[$Preset])
    } elseif ($IncludeDataDb) {
        $resolved = @($presets['recommended'])
    } else {
        $resolved = @($presets['light'])
    }
    if ($IncludeMediaCache) {
        foreach ($g in @('cache.images', 'cache.thumbs')) {
            if ($resolved -notcontains $g) { $resolved += $g }
        }
    }
    if ($IncludeCacheDebug -and ($resolved -notcontains 'cache.debug')) {
        $resolved += 'cache.debug'
    }
    return $resolved
}

function Get-NmerMigrationEntries {
    param(
        [string]$Root,
        [string[]]$Groups = @(),
        [string]$Preset = 'recommended',
        [bool]$IncludeDataDb = $true,
        [bool]$IncludeMediaCache = $false,
        [bool]$IncludeCacheDebug = $false
    )
    $groupIds = Resolve-NmerMigrationGroups -Root $Root -Preset $Preset -Groups $Groups `
        -IncludeDataDb $IncludeDataDb -IncludeMediaCache $IncludeMediaCache -IncludeCacheDebug $IncludeCacheDebug
    $catalog = Get-NmerMigrationGroupCatalog -Root $Root
    $byId = @{}
    foreach ($g in $catalog) { $byId[$g.id] = $g }
    $entries = @()
    $seen = @{}
    foreach ($gid in $groupIds) {
        if (-not $byId.ContainsKey($gid)) { continue }
        foreach ($e in $byId[$gid].entries) {
            if ($seen.ContainsKey($e.id)) { continue }
            $seen[$e.id] = $true
            $entries += $e
        }
    }
    return $entries
}

function Get-NmerMigrationSensitiveFieldNames {
    return @('apiKey', 'apiKeys', 'llmApiKeys', 'options.llmApiKeys')
}

function Resolve-NmerMigrationSourcePath {
    param(
        [string]$Root,
        [hashtable]$Item
    )
    if ($Item.srcPath -and (Test-Path -LiteralPath $Item.srcPath)) {
        return $Item.srcPath
    }
    return Join-Path $Root $Item.path
}

function Resolve-NmerMigrationDestPath {
    param(
        [string]$Root,
        [hashtable]$Item
    )
    if ($Item.srcPath -and $Item.path -match '^Cache\\') {
        $cacheRoot = Get-NmerUserCacheRoot -Root $Root
        $leaf = Split-Path -Leaf $Item.path
        return Join-Path $cacheRoot $leaf
    }
    return Join-Path $Root $Item.path
}

function Get-NmerDirSizeBytes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    if (-not (Get-Item -LiteralPath $Path).PSIsContainer) {
        return (Get-Item -LiteralPath $Path).Length
    }
    $total = 0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $total += $_.Length
    }
    return $total
}

function Format-NmerBytes {
    param([long]$n)
    if ($n -lt 1024) { return "$n B" }
    if ($n -lt 1048576) { return "{0:N1} KB" -f ($n / 1024) }
    if ($n -lt 1073741824) { return "{0:N2} MB" -f ($n / 1048576) }
    return "{0:N2} GB" -f ($n / 1073741824)
}

function Get-NmerMigrationOptionsInfo {
    param([string]$Root)
    $catalog = Get-NmerMigrationGroupCatalog -Root $Root
    $presets = Get-NmerMigrationPresets
    $groups = @()
    $total = 0
    foreach ($g in $catalog) {
        $bytes = 0
        $exists = $false
        foreach ($e in $g.entries) {
            $abs = Resolve-NmerMigrationSourcePath -Root $Root -Item $e
            if (Test-Path -LiteralPath $abs) {
                $exists = $true
                $bytes += Get-NmerDirSizeBytes -Path $abs
            }
        }
        $total += $bytes
        $groups += @{
            id = $g.id
            category = $g.category
            label = $g.label
            hint = $g.hint
            default = [bool]$g.default
            bytes = $bytes
            sizeText = (Format-NmerBytes $bytes)
            exists = $exists
        }
    }
    $presetMeta = @(
        @{ id = 'recommended'; label = 'Recommended'; description = 'config + state + DBs, no image cache'; groups = $presets.recommended },
        @{ id = 'light'; label = 'Light'; description = 'local + JSON state only'; groups = $presets.light },
        @{ id = 'full'; label = 'Full backup'; description = 'recommended + images/thumbs/temp'; groups = $presets.full },
        @{ id = 'custom'; label = 'Custom'; description = 'pick groups below'; groups = @() }
    )
    return @{
        groups = $groups
        presets = $presetMeta
        totalBytes = $total
        totalText = (Format-NmerBytes $total)
    }
}
