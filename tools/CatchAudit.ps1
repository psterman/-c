param(
    [string]$Root = "",
    [string]$OutPath = ""
)

foreach ($rel in @("_Resolve.ps1", "ci\_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$modules = Join-Path $Root "modules"
if (-not $OutPath) {
    $OutPath = Join-Path $Root "Cache\debug\catch_audit.csv"
}

$allowlist = @(
    "NmerCatch.ahk",
    "SqlBatchHelper.ahk",
    "StartupSqlRegistry.ahk"
)

$rows = New-Object System.Collections.Generic.List[object]

Get-ChildItem -Path $modules -Filter "*.ahk" -File | ForEach-Object {
    $file = $_.Name
    $lines = Get-Content -LiteralPath $_.FullName -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNo = $i + 1
        $line = $lines[$i]
        $trim = $line.Trim()

        if ($trim -match 'catch\s+as\s+\w+') {
            if ($trim -match 'NmerCatch\s*\(') {
                $rows.Add([pscustomobject]@{ file = $file; line = $lineNo; category = "nmer_catch"; snippet = $trim })
            } else {
                $rows.Add([pscustomobject]@{ file = $file; line = $lineNo; category = "catch_as_named"; snippet = $trim })
            }
            continue
        }

        if ($allowlist -contains $file) { continue }

        if ($trim -match 'catch\s*\{') {
            if ($trim -match 'catch\s*\{\s*\}') {
                $rows.Add([pscustomobject]@{ file = $file; line = $lineNo; category = "bare_empty"; snippet = $trim })
            } else {
                $rows.Add([pscustomobject]@{ file = $file; line = $lineNo; category = "bare_block"; snippet = $trim })
            }
        }
    }
}

$outDir = Split-Path -Parent $OutPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$rows | Sort-Object file, line | Export-Csv -LiteralPath $OutPath -NoTypeInformation -Encoding UTF8

Write-Output "== Catch Audit =="
Write-Output "root=$Root"
Write-Output "out=$OutPath"
Write-Output "total=$($rows.Count)"
$rows | Group-Object category | ForEach-Object { Write-Output ("  {0}={1}" -f $_.Name, $_.Count) }
