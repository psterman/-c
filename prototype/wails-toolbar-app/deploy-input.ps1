# 将 wails build 产物复制到仓库 bin/，便于确认已替换为新版本
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $root
$src = Join-Path $PSScriptRoot "build\bin\nmer-wails-input.exe"
$binDir = Join-Path $repo "bin"
$dst = Join-Path $binDir "nmer-wails-input.exe"
if (-not (Test-Path $src)) {
    Write-Error "请先在本目录执行: wails build`n缺少: $src"
}
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
Copy-Item -LiteralPath $src -Destination $dst -Force
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Set-Content -Path (Join-Path $repo "Cache\wails_input_build.txt") -Value $stamp -Encoding UTF8
Write-Host "已部署: $dst"
Write-Host "构建时间戳: $stamp"
