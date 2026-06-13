# Hybrid 运行终验一键入口（自动门禁 + 打开看板）
param(
    [string]$RepoRoot = "",
    [switch]$RunOpenClawSmoke,
    [switch]$CaptureAhkReferenceFirst,
    [switch]$RunManualSignoff,
    [switch]$RunCpPipeline
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}

Write-Host "== Hybrid Signoff: $RepoRoot ==" -ForegroundColor Cyan

if ($CaptureAhkReferenceFirst) {
    Write-Host "[ref] capture ahk memory reference (set floatingToolbarHost=ahk, reload, then run without this flag)"
    & (Join-Path $here "Capture-HybridMemoryReference.ps1") -RepoRoot $RepoRoot -Mode ahk
}

if ($RunManualSignoff) {
    & (Join-Path $here "Run-HybridManualSignoff.ps1") -RepoRoot $RepoRoot -RefreshDashboard
    exit $LASTEXITCODE
}

if ($RunCpPipeline) {
    & (Join-Path $here "Run-HybridCpSignoffPipeline.ps1") -RepoRoot $RepoRoot
    exit $LASTEXITCODE
}

$openArgs = @{ RepoRoot = $RepoRoot }
if ($RunOpenClawSmoke) { $openArgs["RunOpenClawSmoke"] = $true }
& (Join-Path $here "Open-HybridSignoffDashboard.ps1") @openArgs
exit $LASTEXITCODE
