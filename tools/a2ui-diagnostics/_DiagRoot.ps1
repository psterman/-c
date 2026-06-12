# 诊断工具包公共路径（各子目录脚本 dot-source 本文件）
function Get-DiagKitRoot {
    param([string]$From = $PSScriptRoot)
    $p = $From
    for ($i = 0; $i -lt 6; $i++) {
        if (Test-Path (Join-Path $p "_DiagRoot.ps1")) {
            return (Resolve-Path $p).Path
        }
        $next = Split-Path $p -Parent
        if (-not $next -or $next -eq $p) { break }
        $p = $next
    }
    throw "未找到 a2ui-diagnostics 根目录（缺少 _DiagRoot.ps1），起始于: $From"
}

function Get-DiagRepoRoot {
    param([string]$From = $PSScriptRoot)
    $kit = Get-DiagKitRoot -From $From
    return (Resolve-Path (Join-Path $kit "..\..")).Path
}

function Join-DiagScript {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [string]$From = $PSScriptRoot
    )
    Join-Path (Get-DiagKitRoot -From $From) ($RelativePath -replace '/', '\')
}

function Get-SearchCoreSignoffSnapshot {
    $running = [bool](Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue)
    $scanPhase = "unknown"
    $fulltextReady = $false
    $indexLifecycle = "unknown"
    $privateMiB = $null
    $indexMappedMiB = $null

    try {
        $status = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 3
        if ($status) {
            $running = $true
            if ($status.scanPhase) { $scanPhase = [string]$status.scanPhase }
            elseif ($status.phase) { $scanPhase = [string]$status.phase }
            $fulltextReady = [bool]$status.ready
            if ($status.indexLifecycle) {
                if ($status.indexLifecycle -is [string]) {
                    $indexLifecycle = [string]$status.indexLifecycle
                } elseif ($status.indexLifecycle.cutoverState) {
                    $indexLifecycle = [string]$status.indexLifecycle.cutoverState
                } elseif ($status.indexLifecycle.role) {
                    $indexLifecycle = [string]$status.indexLifecycle.role
                } else {
                    $indexLifecycle = ($status.indexLifecycle | ConvertTo-Json -Compress)
                }
            }
        }
    } catch {
        if (-not $running) { $scanPhase = "not_running" }
    }

    try {
        $mem = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/memory" -TimeoutSec 3
        if ($mem -and $mem.memory) {
            $running = $true
            if ($null -ne $mem.memory.privateMiB) { $privateMiB = [double]$mem.memory.privateMiB }
            if ($null -ne $mem.memory.indexMappedMiB) { $indexMappedMiB = [double]$mem.memory.indexMappedMiB }
            if ($mem.memory.idleLifecycle -and $indexLifecycle -eq "unknown") {
                $indexLifecycle = [string]$mem.memory.idleLifecycle
            }
        }
    } catch {}

    return [ordered]@{
        searchCore = [ordered]@{
            running        = $running
            scanPhase      = $scanPhase
            privateMiB     = $privateMiB
            indexMappedMiB = $indexMappedMiB
        }
        fulltextReady  = $fulltextReady
        indexLifecycle = $indexLifecycle
    }
}

function Get-ReferenceScanPhase($ref) {
    if (-not $ref) { return "missing" }
    if ($ref.searchCore -and $ref.searchCore.scanPhase) { return [string]$ref.searchCore.scanPhase }
    if ($ref.indexLifecycle) { return [string]$ref.indexLifecycle }
    return "unknown"
}
