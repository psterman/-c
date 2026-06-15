param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$modules = Join-Path $Root "modules"
$allowlist = @(
    "NmerCatch.ahk",
    "SqlBatchHelper.ahk",
    "StartupSqlRegistry.ahk"
)

$hits = @()
Get-ChildItem -Path $modules -Filter "*.ahk" -File | ForEach-Object {
    if ($allowlist -contains $_.Name) { return }
    $lines = Select-String -LiteralPath $_.FullName -Pattern 'catch\s*\{\s*\}' -AllMatches
    foreach ($m in $lines) {
        $hits += "$($_.Name):$($m.LineNumber):$($m.Line.Trim())"
    }
}

Write-Output "== Validate Catch Policy =="
Write-Output "root=$Root"
if ($hits.Count -eq 0) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL bare_catch_count=$($hits.Count)"
$hits | Select-Object -First 40 | ForEach-Object { Write-Output $_ }
exit 1
