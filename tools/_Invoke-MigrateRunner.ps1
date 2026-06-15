param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "ci\_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$fso = New-Object -ComObject Scripting.FileSystemObject
$shortRoot = $fso.GetFolder($Root).ShortPath
$runner = Join-Path $env:TEMP "nmer_migrate_runner.ahk"
$outFile = Join-Path $env:TEMP "nmer_migrate_runner.out"
if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
$env:NMRE_ROOT = $Root

$content = @'
#Requires AutoHotkey v2.0
#Include "{ROOT}\modules\LocalPaths.ahk"
#Include "{ROOT}\modules\NmerCatch.ahk"
#Include "{ROOT}\lib\ahk\Jxon.ahk"
#Include "{ROOT}\modules\SecretVault.ahk"
#Include "{ROOT}\modules\Nmer_SecretStore.ahk"
ok := Nmer_SecretStore_MigrateUserStudioPlaintext()
FileAppend("ok=" . (ok ? "1" : "0") . "`n", EnvGet("TEMP") . "\nmer_migrate_runner.out", "UTF-8")
ExitApp(ok ? 0 : 1)
'@ -replace '\{ROOT\}', $shortRoot

Set-Content -LiteralPath $runner -Value $content -Encoding UTF8

$ahk = "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path -LiteralPath $ahk)) { $ahk = "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey.exe" }
if (-not (Test-Path -LiteralPath $ahk)) {
    Write-Output "RESULT=FAIL no AutoHotkey"
    exit 1
}

& $ahk $runner
if (Test-Path -LiteralPath $outFile) { Get-Content -LiteralPath $outFile }
Remove-Item Env:NMRE_ROOT -ErrorAction SilentlyContinue
