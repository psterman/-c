param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$ahk = Join-Path $Root "modules\NiumaTtyd.ahk"
if (-not (Test-Path -LiteralPath $ahk)) {
    Write-Output "RESULT=FAIL missing NiumaTtyd.ahk"
    exit 1
}

$text = Get-Content -LiteralPath $ahk -Raw -Encoding UTF8
$hits = @()
if ($text -notmatch '-i\s+127\.0\.0\.1') { $hits += "missing -i 127.0.0.1 bind" }
if ($text -match '-i\s+0\.0\.0\.0') { $hits += "found -i 0.0.0.0 (LAN exposure risk)" }
if ($text -match 'http://0\.0\.0\.0') { $hits += "found http://0.0.0.0 URL" }

Write-Output "== Validate Ttyd Bind =="
Write-Output "root=$Root"
if ($hits.Count -eq 0) {
    Write-Output "RESULT=PASS ttyd binds 127.0.0.1 only"
    exit 0
}
Write-Output "RESULT=FAIL"
$hits | ForEach-Object { Write-Output $_ }
exit 1
