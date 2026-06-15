param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$tier1 = @(
    "LegacyClipboardListView.ahk",
    "LegacyConfigGui.ahk",
    "ClipboardPanelCore.ahk",
    "ClipboardHistoryPanel.ahk",
    "ClipboardFTS5.ahk"
)

$pattern = 'LIKE\s+''%.*\.'
$hits = @()
foreach ($name in $tier1) {
    $path = Join-Path $Root "modules\$name"
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $lines = Select-String -LiteralPath $path -Pattern $pattern -AllMatches
    foreach ($m in $lines) {
        $line = $m.Line
        if ($line -match 'SqlSafe_|\|\| \?') { continue }
        if ($name -eq 'ClipboardHistoryPanel.ahk' -and $line -match '\.(png|jpg|jpeg|gif|bmp|webp|tiff|ico)') { continue }
        if ($name -eq 'ClipboardHistoryPanel.ahk' -and $line -match "LIKE '%\\\\%'") { continue }
        $hits += "$name`:$($m.LineNumber):$($m.Line.Trim())"
    }
}

Write-Output "== Validate Sql Policy (Tier-1 LIKE concat) =="
Write-Output "root=$Root"
if ($hits.Count -eq 0) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL hits=$($hits.Count)"
$hits | Select-Object -First 30 | ForEach-Object { Write-Output $_ }
exit 1
