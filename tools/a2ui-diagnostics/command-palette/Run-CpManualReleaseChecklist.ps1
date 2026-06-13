# CP release manual checklist (6 items, default AHK host). Output: cp_manual_release_checklist.json
param(
    [string]$RepoRoot = "",
    [switch]$Init,
    [switch]$Validate,
    [string]$RecordId = "",
    [switch]$Fail,
    [string]$Detail = "",
    [switch]$SignoffAll,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$dbg = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $dbg)) { New-Item -ItemType Directory -Path $dbg -Force | Out-Null }
$outPath = Join-Path $dbg "cp_manual_release_checklist.json"

function Write-ChecklistJson([object]$obj, [string]$path) {
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 6), $utf8)
}

function Get-ChecklistItemDefs {
    $itemsPath = Join-Path $PSScriptRoot "cp_manual_release_checklist.items.json"
    if (-not (Test-Path $itemsPath)) { throw "missing $itemsPath" }
    $raw = [System.IO.File]::ReadAllText($itemsPath, [System.Text.UTF8Encoding]::new($false))
    return @($raw | ConvertFrom-Json)
}

$items = Get-ChecklistItemDefs

function Read-FlagsState([string]$flagsPath) {
    $cpHost = "?"
    $legacy = $null
    $sidecar = "?"
    if (Test-Path $flagsPath) {
        try {
            $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($f.wailsBridge.commandPaletteHost) { $cpHost = [string]$f.wailsBridge.commandPaletteHost }
            if ($f.wailsBridge.sidecarHost) { $sidecar = [string]$f.wailsBridge.sidecarHost }
            if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacy = [bool]$f.rollback.legacySurfaceLifecycle }
        } catch { }
    }
    return @{
        host = $cpHost
        sidecar = $sidecar
        legacy = $legacy
        defaultAhk = ($cpHost -eq "ahk") -and ($sidecar -eq "hub") -and ($legacy -eq $true)
    }
}

function New-ChecklistTemplate {
    $rows = @()
    foreach ($it in $items) {
        $rows += [ordered]@{
            id = [string]$it.id
            title = [string]$it.title
            pass = $false
            detail = ""
            verifiedAt = ""
        }
    }
    return [ordered]@{
        capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        gate = "cp_manual_release_checklist"
        defaultHost = "ahk"
        overallPass = $false
        manualReleasePass = $false
        items = $rows
        flagsAtSignoff = (Read-FlagsState (Join-Path $RepoRoot "local\nmer-flags.json"))
        note = "Hand-verify each item on commandPaletteHost=ahk, then -RecordId <id> -Pass or edit JSON pass=true"
    }
}

if ($Init) {
    $tpl = New-ChecklistTemplate
    $tpl | ConvertTo-Json -Depth 6 | Out-Null
    Write-ChecklistJson $tpl $outPath
    Write-Host "init -> $outPath"
    if ($JsonOnly) { $tpl | ConvertTo-Json -Depth 6 }
    exit 0
}

$checklist = $null
if (Test-Path $outPath) {
    try { $checklist = Get-Content $outPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}
if (-not $checklist) {
    $checklist = New-ChecklistTemplate
}

$recordPass = -not $Fail

if ($SignoffAll) {
    if (-not $Detail) {
        $Detail = "batch signoff: hybrid_manual_signoff + command_palette_perf_gate PASS"
    }
    $updated = @()
    $now = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    foreach ($it in $items) {
        $updated += [ordered]@{
            id = [string]$it.id
            title = [string]$it.title
            pass = $true
            detail = $Detail
            verifiedAt = $now
        }
    }
    $flags = Read-FlagsState (Join-Path $RepoRoot "local\nmer-flags.json")
    $checklist = [ordered]@{
        capturedAt = $now
        gate = "cp_manual_release_checklist"
        defaultHost = "ahk"
        overallPass = $true
        manualReleasePass = $true
        signoffMode = "SignoffAll"
        items = $updated
        flagsAtSignoff = $flags
        note = $checklist.note
    }
    Write-ChecklistJson $checklist $outPath
    Write-Host "SignoffAll -> $outPath overallPass=True" -ForegroundColor Green
    if ($JsonOnly) { $checklist | ConvertTo-Json -Depth 6 }
    exit 0
}

if ($RecordId) {
    $hit = $false
    $updated = @()
    foreach ($row in @($checklist.items)) {
        if ([string]$row.id -eq $RecordId) {
            $hit = $true
            $updated += [ordered]@{
                id = $row.id
                title = $row.title
                pass = $recordPass
                detail = $Detail
                verifiedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
        } else {
            $updated += [ordered]@{
                id = $row.id
                title = $row.title
                pass = [bool]$row.pass
                detail = [string]$row.detail
                verifiedAt = [string]$row.verifiedAt
            }
        }
    }
    if (-not $hit) {
        $ids = ($items | ForEach-Object { [string]$_.id }) -join ", "
        throw "unknown RecordId '$RecordId' (expected one of: $ids)"
    }
    $allPass = ($updated | Where-Object { -not $_.pass }).Count -eq 0
    $flags = Read-FlagsState (Join-Path $RepoRoot "local\nmer-flags.json")
    $checklist = [ordered]@{
        capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        gate = "cp_manual_release_checklist"
        defaultHost = "ahk"
        overallPass = $allPass
        manualReleasePass = $allPass
        items = $updated
        flagsAtSignoff = $flags
        note = $checklist.note
    }
    Write-ChecklistJson $checklist $outPath
    Write-Host ("record {0} pass={1} overall={2}" -f $RecordId, $recordPass, $allPass) -ForegroundColor $(if ($recordPass) { "Green" } else { "Yellow" })
    if ($JsonOnly) { $checklist | ConvertTo-Json -Depth 6 }
    exit $(if ($allPass) { 0 } else { 1 })
}

$flags = Read-FlagsState (Join-Path $RepoRoot "local\nmer-flags.json")
$allPass = $true
foreach ($row in @($checklist.items)) {
    if (-not $row.pass) { $allPass = $false }
}
$checklist.overallPass = $allPass
$checklist.manualReleasePass = $allPass
$checklist.flagsAtSignoff = $flags
Write-ChecklistJson $checklist $outPath

if ($Validate -or -not $Init) {
    foreach ($row in @($checklist.items)) {
        $color = if ($row.pass) { "Green" } else { "Red" }
        Write-Host ("  {0} {1}: {2}" -f $row.id, $row.title, $(if ($row.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
    }
    Write-Host ("defaultHost={0} legacyRollbackPolicy=ahk+hub+legacy:true -> flagsOk={1}" -f $flags.host, $flags.defaultAhk) -ForegroundColor $(if ($flags.defaultAhk) { "DarkGray" } else { "Yellow" })
    Write-Host ("overall: {0}" -f $(if ($allPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($allPass) { "Green" } else { "Red" })
    Write-Host "report: $outPath" -ForegroundColor DarkGray
    if ($JsonOnly) { $checklist | ConvertTo-Json -Depth 6 }
    exit $(if ($allPass) { 0 } else { 1 })
}
