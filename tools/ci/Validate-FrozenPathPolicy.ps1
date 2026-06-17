param(
    [string]$Root = "",
    [switch]$Strict,
    [switch]$ChangedOnly
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$defaultScanRel = @(
    "README.md",
    "md\AGENTS.md",
    "md\README.md",
    "docs\nmer-conventions.md",
    "docs\stack-governance.md",
    "docs\pull-request-checklist.md"
)

$frozenPatterns = @(
    @{ Label = "a2ui-diagnostics"; Regex = 'tools[/\\]a2ui-diagnostics[/\\][A-Za-z0-9_./\\-]+' }
    @{ Label = "a2ui-rollout-archive"; Regex = 'docs[/\\]a2ui-rollout-[A-Za-z0-9_.-]+\.md' }
)

function Test-AllowlistMatch {
    param([string]$HitPath, [string[]]$AllowGlobs)
    $norm = ($HitPath -replace '\\', '/').Trim()
    foreach ($glob in $AllowGlobs) {
        $g = ($glob -replace '\\', '/').Trim()
        if ($g -match '[\*\?]') {
            if ($norm -like ($g -replace '/', '\')) { return $true }
            $like = $g -replace '\.', '\.' -replace '\*\*', '.*' -replace '\*', '[^/\\]*' -replace '\?', '.'
            if ($norm -match "^$like$") { return $true }
        } else {
            if ($norm -eq $g) { return $true }
            if ($norm.StartsWith($g.TrimEnd('/'))) { return $true }
        }
    }
    return $false
}

$allowPath = Join-Path $PSScriptRoot "frozen-path-allowlist.txt"
$allowGlobs = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $allowPath) {
    Get-Content -LiteralPath $allowPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        [void]$allowGlobs.Add($line)
    }
}

function Get-ChangedDocPaths {
    param([string]$RepoRoot)
    $list = New-Object System.Collections.Generic.List[string]
    try {
        Push-Location $RepoRoot
        $diff = git diff --name-only HEAD 2>$null
        if (-not $diff) { $diff = git diff --name-only 2>$null }
        foreach ($p in @($diff)) {
            $p = ($p -replace '/', '\').Trim()
            if ($p -match '\.md$') { [void]$list.Add($p) }
        }
    } catch {
    } finally {
        Pop-Location
    }
    return $list
}

$scanRel = New-Object System.Collections.Generic.List[string]
foreach ($r in $defaultScanRel) { [void]$scanRel.Add($r) }

if ($ChangedOnly) {
    foreach ($p in (Get-ChangedDocPaths -RepoRoot $Root)) {
        if (-not $scanRel.Contains($p)) { [void]$scanRel.Add($p) }
    }
}

$hits = New-Object System.Collections.Generic.List[string]
$allowedHits = New-Object System.Collections.Generic.List[string]

foreach ($rel in $scanRel) {
    $full = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $lines = Get-Content -LiteralPath $full -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        foreach ($fp in $frozenPatterns) {
            $m = [regex]::Matches($line, $fp.Regex)
            foreach ($match in $m) {
                $captured = ($match.Value -replace '[`''"]+$', '').TrimEnd('.', ',', ';')
                $key = "$rel`:$($i + 1):$($fp.Label):$captured"
                if (Test-AllowlistMatch -HitPath $captured -AllowGlobs $allowGlobs) {
                    [void]$allowedHits.Add($key)
                } else {
                    [void]$hits.Add($key)
                }
            }
        }
    }
}

$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report = Join-Path $reportDir "frozen_path_policy_report.txt"
$out = New-Object System.Collections.Generic.List[string]
$out.Add("== Frozen Path Policy $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==")
$out.Add("root=$Root")
$out.Add("changedOnly=$ChangedOnly strict=$Strict")
$out.Add("scanCount=$($scanRel.Count) allowlistCount=$($allowGlobs.Count)")
$out.Add("")

if ($hits.Count -eq 0) {
    $out.Add("POLICY=PASS")
    $exit = 0
} else {
    $out.Add("POLICY=FAIL hits=$($hits.Count)")
    foreach ($h in $hits) { $out.Add("HIT $h") }
    $exit = 1
}
if ($allowedHits.Count -gt 0) {
    $out.Add("")
    $out.Add("allowed=$($allowedHits.Count)")
    foreach ($a in $allowedHits) { $out.Add("OK $a") }
}

$out | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "report=$report"
$out | ForEach-Object { Write-Output $_ }
exit $exit
