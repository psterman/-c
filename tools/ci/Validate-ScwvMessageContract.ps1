param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$manifestPath = Join-Path $PSScriptRoot "scwv-contract-types.json"
$contractMd = Join-Path $Root "docs\scwv-message-contract.md"
$scwvAhk = Join-Path $Root "modules\SearchCenterWebViewCore.ahk"
$html = Join-Path $Root "html\SearchCenter.html"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Output "RESULT=FAIL missing_manifest=$manifestPath"
    exit 1
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifestInbound = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($t in $manifest.inbound.webToAhk) { [void]$manifestInbound.Add([string]$t) }

$ahkOnly = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
if ($manifest.inbound.ahkOnly) {
    foreach ($t in $manifest.inbound.ahkOnly) { [void]$ahkOnly.Add([string]$t) }
}

function Get-ScwvWebInboundCases {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($text -notmatch '(?s)SCWV_ProcessWebMessageJson\(jsonStr\)\s*\{.*?switch action\s*\{(?<body>.*?)\n    \}\s*\n    \} catch') {
        throw "cannot locate SCWV_ProcessWebMessageJson switch"
    }
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($m in [regex]::Matches($Matches['body'], 'case\s+"([^"]+)"')) {
        foreach ($part in ($m.Groups[1].Value -split ',\s*')) {
            $p = $part.Trim().Trim('"')
            if ($p) { [void]$set.Add($p) }
        }
    }
    return $set
}

function Get-HtmlPostToAhkTypes {
    param([string]$Path)
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    foreach ($line in $lines) {
        if ($line -notmatch 'postToAhk') { continue }
        foreach ($m in [regex]::Matches($line, 'type:\s*"([^"]+)"')) {
            [void]$set.Add($m.Groups[1].Value)
        }
    }
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $Path -Raw -Encoding UTF8), 'postToAhk\(\s*\{[\s\S]*?type:\s*"([^"]+)"')) {
        [void]$set.Add($m.Groups[1].Value)
    }
    return $set
}

$ahkCases = Get-ScwvWebInboundCases -Path $scwvAhk
$htmlTypes = Get-HtmlPostToAhkTypes -Path $html

$hits = New-Object System.Collections.Generic.List[string]

foreach ($t in $htmlTypes) {
    if (-not $manifestInbound.Contains($t)) {
        [void]$hits.Add("html_not_in_manifest:$t")
    }
}

foreach ($t in $ahkCases) {
    if (-not $manifestInbound.Contains($t)) {
        [void]$hits.Add("ahk_not_in_manifest:$t")
    }
}

foreach ($t in $manifestInbound) {
    if (-not $ahkCases.Contains($t)) {
        [void]$hits.Add("manifest_not_in_ahk:$t")
    }
    if (-not $htmlTypes.Contains($t) -and -not $ahkOnly.Contains($t)) {
        [void]$hits.Add("manifest_not_in_html_or_ahkOnly:$t")
    }
}

$md = Get-Content -LiteralPath $contractMd -Raw -Encoding UTF8
$expectedMaturity = [string]$manifest.maturity
if ($expectedMaturity -eq "production") {
    if ($md -notmatch '\*\*production\*\*') {
        [void]$hits.Add("contract_md_not_marked_production")
    }
} elseif ($expectedMaturity -eq "stable") {
    if ($md -notmatch '\*\*stable\*\*') {
        [void]$hits.Add("contract_md_not_marked_stable")
    }
}

$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report = Join-Path $reportDir "scwv_contract_drift_report.txt"
$out = New-Object System.Collections.Generic.List[string]
$out.Add("== SCWV Contract Drift $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==")
$out.Add("manifest=$manifestPath maturity=$($manifest.maturity)")
$out.Add("manifest_inbound=$($manifestInbound.Count) ahk_cases=$($ahkCases.Count) html_postToAhk=$($htmlTypes.Count)")
$out.Add("")

if ($hits.Count -eq 0) {
    $out.Add("RESULT=PASS")
    $exit = 0
} else {
    $out.Add("RESULT=FAIL hits=$($hits.Count)")
    foreach ($h in $hits) { $out.Add("HIT $h") }
    $exit = 1
}

$out | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "report=$report"
$out | ForEach-Object { Write-Output $_ }
exit $exit
