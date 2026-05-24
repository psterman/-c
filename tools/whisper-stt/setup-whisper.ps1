# 一键检查 / 下载 Whisper small 模型
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$py = Join-Path $here ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Error "缺少 .venv，请先在 tools\whisper-stt 创建虚拟环境并 pip install faster-whisper huggingface_hub"
}
& $py (Join-Path $here "download_model.py")
Write-Host "完成。请重载牛马脚本后再试语音输入。"
