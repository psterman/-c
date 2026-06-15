$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$fso = New-Object -ComObject Scripting.FileSystemObject
$shortRoot = $fso.GetFolder($root).ShortPath
$runner = Join-Path $env:TEMP "nmer_llm_smoke_$([guid]::NewGuid().ToString('N')).ahk"
$outFile = Join-Path $env:TEMP "nmer_llm_smoke.out"
if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
@'
#Requires AutoHotkey v2.0
#Include "{ROOT}\modules\LocalPaths.ahk"
#Include "{ROOT}\modules\NmerCatch.ahk"
#Include "{ROOT}\lib\ahk\Jxon.ahk"
#Include "{ROOT}\modules\FuncExists.ahk"
#Include "{ROOT}\modules\SecretVault.ahk"
#Include "{ROOT}\modules\Nmer_SecretStore.ahk"
#Include "{ROOT}\modules\NiumaOllama.ahk"
#Include "{ROOT}\modules\LlmApiPing.ahk"
#Include "{ROOT}\modules\UserStudio.ahk"
#Include "{ROOT}\modules\Nmer_LlmProvider_Oai.ahk"
#Include "{ROOT}\modules\Nmer_LlmProvider_Ollama.ahk"
#Include "{ROOT}\modules\Nmer_LlmProvider.ahk"

out := EnvGet("TEMP") . "\nmer_llm_smoke.out"
line := ""
try {
    reg := Nmer_Llm_Registry()
    if !(reg is Array) || reg.Length < 2
        throw Error("registry")
    active := Nmer_Llm_GetActive()
    if !(active is Map) || !active.Has("protocolId")
        throw Error("getActive")
    unified := Nmer_Llm_BuildUnifiedPayload()
    if !(unified is Map) || !unified.Has("providers")
        throw Error("unified")
    cfg := Map("protocolId", "openai", "vendor", "openai", "model", "gpt-4o-mini", "baseUrl", "https://api.openai.com/v1", "apiKey", "")
    r := Nmer_Llm_Route("ping", cfg, 2000)
    if !(r is Map) || !r.Has("ok")
        throw Error("route")
    line := "RESULT=PASS registry=" . reg.Length . " proto=" . active["protocolId"]
} catch as e {
    line := "RESULT=FAIL " . e.Message
}
FileAppend(line . "`n", out, "UTF-8")
ExitApp(InStr(line, "PASS") ? 0 : 1)
'@ -replace '\{ROOT\}', $shortRoot | Set-Content -LiteralPath $runner -Encoding UTF8

$ahk = "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path -LiteralPath $ahk)) { $ahk = "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey.exe" }
if (-not (Test-Path -LiteralPath $ahk)) {
    Write-Output "RESULT=SKIP no AutoHotkey"
    exit 0
}
& $ahk $runner
if (Test-Path -LiteralPath $outFile) { Get-Content -LiteralPath $outFile }
Remove-Item -LiteralPath $runner -Force -ErrorAction SilentlyContinue
