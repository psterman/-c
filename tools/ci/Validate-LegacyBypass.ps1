param(
    [string]$Root = "",
    [switch]$Strict
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$excludeFiles = @(
    "LegacyConfigGui.ahk",
    "LegacyClipboardListView.ahk",
    "LegacyGuardrails.ahk",
    "LegacyPromptQuickPadGui.ahk",
    "SearchCenterLegacyGui.ahk"
)

$patterns = [ordered]@{
    LegacyConfigGui_Show = '\bLegacyConfigGui_Show\s*\('
    ShowClipboardManager   = '\bShowClipboardManager\s*\('
}

$allowPath = Join-Path $PSScriptRoot "legacy-bypass-allowlist.txt"
$allowed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $allowPath) {
    Get-Content -LiteralPath $allowPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        [void]$allowed.Add($line)
    }
}

$scanFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$modulesDir = Join-Path $Root "modules"
if (Test-Path -LiteralPath $modulesDir) {
    Get-ChildItem -Path $modulesDir -Filter "*.ahk" -File | ForEach-Object {
        if ($excludeFiles -contains $_.Name) { return }
        [void]$scanFiles.Add($_)
    }
}
$mainScript = $null
if (Get-Command Nmer-ResolveMainAhk -ErrorAction SilentlyContinue) {
    try { $mainScript = Get-Item -LiteralPath (Nmer-ResolveMainAhk -Root $Root) }
    catch { }
}
if (-not $mainScript) {
    $literalMain = Join-Path $Root "牛马.ahk"
    if (Test-Path -LiteralPath $literalMain) {
        $mainScript = Get-Item -LiteralPath $literalMain
    } else {
        $mainScript = Get-ChildItem -LiteralPath $Root -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^(VirtualKeyboard|probe_|test_|_)' } |
            Sort-Object Length -Descending |
            Select-Object -First 1
    }
}
if ($mainScript) {
    [void]$scanFiles.Add($mainScript)
}

$hits = New-Object System.Collections.Generic.List[string]
$allowedHits = New-Object System.Collections.Generic.List[string]

foreach ($file in $scanFiles) {
    $rel = if ($mainScript -and $file.FullName -eq $mainScript.FullName) { $mainScript.Name } else { "modules\" + $file.Name }
    foreach ($entry in $patterns.GetEnumerator()) {
        $symbol = [string]$entry.Key
        $regex = [string]$entry.Value
        $matches = Select-String -LiteralPath $file.FullName -Pattern $regex -AllMatches
        foreach ($m in $matches) {
            $key = "$rel`:$($m.LineNumber):$symbol"
            if ($allowed.Contains($key)) {
                [void]$allowedHits.Add($key)
            } else {
                [void]$hits.Add("$key`:$($m.Line.Trim())")
            }
        }
    }
}

Write-Output "== Validate Legacy Bypass =="
Write-Output "root=$Root"
Write-Output "strict=$($Strict.IsPresent)"
Write-Output "allowlist=$allowPath allowed_entries=$($allowed.Count) matched_allow=$($allowedHits.Count)"

if ($hits.Count -eq 0) {
    Write-Output "RESULT=PASS"
    exit 0
}

Write-Output "RESULT=$($(if ($Strict) { 'FAIL' } else { 'WARN' })) new_bypass_count=$($hits.Count)"
$hits | Select-Object -First 40 | ForEach-Object { Write-Output $_ }
if ($Strict) { exit 1 }
exit 0
