param(
    [string]$Root = "",
    [string]$OutDir = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$debugDir = if ($OutDir) { $OutDir } else { Join-Path $Root "Cache\debug" }
if (-not (Test-Path -LiteralPath $debugDir)) {
    New-Item -ItemType Directory -Path $debugDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundle = Join-Path $debugDir "searchcore_logs_$stamp.txt"

$files = @(
    (Join-Path $debugDir "searchcore_lifecycle.jsonl"),
    (Join-Path $debugDir "searchcore_launch.log"),
    (Join-Path $debugDir "scwv_trace.log")
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("== SearchCore log bundle $stamp ==")
[void]$sb.AppendLine("root=$Root")
foreach ($f in $files) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---- $f ----")
    if (Test-Path -LiteralPath $f) {
        Get-Content -LiteralPath $f -Tail 200 -Encoding UTF8 | ForEach-Object { [void]$sb.AppendLine($_) }
    } else {
        [void]$sb.AppendLine("(missing)")
    }
}

$sb.ToString() | Set-Content -LiteralPath $bundle -Encoding UTF8
Write-Output "bundle=$bundle"
exit 0
