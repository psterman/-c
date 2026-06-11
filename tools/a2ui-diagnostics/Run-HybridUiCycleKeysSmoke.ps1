# UI cycle fallback via CapsLock hotkeys + surface_runtime.ndjson verification
param(
    [string]$RepoRoot = "",
    [int]$Rounds = 10,
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not $OutPath) { $OutPath = Join-Path $debugDir "hybrid_ui_cycle_keys_smoke.json" }
$rtPath = Join-Path $debugDir "surface_runtime.ndjson"

function Get-IntentOpenCount([string]$path, [string]$surface, [int]$afterLine) {
    if (-not (Test-Path $path)) { return 0 }
    $n = 0
    $i = 0
    foreach ($line in (Get-Content $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        $i++
        if ($i -le $afterLine) { continue }
        if ($line -match '"type"\s*:\s*"intent_open"' -and $line -match "`"$surface`"") { $n++ }
    }
    return $n
}

$lineBefore = 0
if (Test-Path $rtPath) { $lineBefore = @(Get-Content $rtPath -Encoding UTF8).Count }

& (Join-Path $PSScriptRoot "Invoke-HybridManualUiKeys.ps1") -Rounds $Rounds

Start-Sleep -Seconds 2
$cpOpens = Get-IntentOpenCount $rtPath "command_palette" $lineBefore
$scOpens = Get-IntentOpenCount $rtPath "search_center" $lineBefore
# SC chord is harder to simulate; accept cp>=rounds and sc>=max(3, rounds-3)
$scNeed = [math]::Max(3, $Rounds - 3)
$pass = ($cpOpens -ge $Rounds) -and ($scOpens -ge $scNeed)

$report = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    mode       = "capslock_keys_fallback"
    rounds     = $Rounds
    cpOpens    = $cpOpens
    scOpens    = $scOpens
    pass       = $pass
}
$report | ConvertTo-Json | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "hybrid_ui_cycle_keys -> $OutPath pass=$pass cpOpens=$cpOpens scOpens=$scOpens"
if (-not $pass) { exit 1 }
exit 0
