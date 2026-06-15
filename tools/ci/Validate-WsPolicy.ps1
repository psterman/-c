param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$hits = @()

$wshub = Join-Path $Root "apps\nmer-wails\poc\wshub.go"
$ndHub = Join-Path $Root "tools\native-drop-bridge\hub.go"
$wsAuth = Join-Path $Root "modules\WsHubAuth.ahk"
$mainAhk = Join-Path $Root "牛马.ahk"
if (-not (Test-Path -LiteralPath $mainAhk)) {
    $mainAhk = Nmer-ResolveMainAhk -Root $Root
}

if (-not (Test-Path -LiteralPath $wshub)) { $hits += "missing=wshub.go" }
elseif (-not (Select-String -LiteralPath $wshub -Pattern 'func wsAuthOK' -Quiet)) { $hits += "wshub.go:missing wsAuthOK" }
elseif (-not (Select-String -LiteralPath $wshub -Pattern 'NMER_WS_HUB_TOKEN' -Quiet)) { $hits += "wshub.go:missing NMER_WS_HUB_TOKEN" }

if (-not (Test-Path -LiteralPath $ndHub)) { $hits += "missing=native-drop-bridge/hub.go" }
elseif (-not (Select-String -LiteralPath $ndHub -Pattern 'wsToken' -Quiet)) { $hits += "hub.go:missing wsToken check" }

if (-not (Test-Path -LiteralPath $wsAuth)) { $hits += "missing=WsHubAuth.ahk" }
elseif (-not (Select-String -LiteralPath $wsAuth -Pattern 'Nmer_GetOrCreateWsHubToken' -Quiet)) { $hits += "WsHubAuth.ahk:missing token API" }

if (Test-Path -LiteralPath $mainAhk) {
    if (-not (Select-String -LiteralPath $mainAhk -Pattern 'WsHubAuth' -Quiet)) { $hits += "牛马.ahk:missing WsHubAuth include" }
    if (-not (Select-String -LiteralPath $mainAhk -Pattern 'Nmer_EnsureWsHubTokenEnv' -Quiet)) { $hits += "牛马.ahk:missing Nmer_EnsureWsHubTokenEnv boot" }
}

Write-Output "== Validate WS Policy =="
Write-Output "root=$Root"
if ($hits.Count -eq 0) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL hits=$($hits.Count)"
$hits | ForEach-Object { Write-Output $_ }
exit 1
