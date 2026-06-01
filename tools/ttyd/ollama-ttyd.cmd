@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
rem 降低 ttyd 子进程内 OpenBLAS/OMP 多线程大块分配导致失败的概率
set OPENBLAS_NUM_THREADS=1
set OMP_NUM_THREADS=1
set OLLAMA_NUM_PARALLEL=1
set GOTOBLAS_BLOCK_FACTOR=64
echo.
echo [牛马 nmer] Ollama 终端（已限制 OpenBLAS 为单线程）
echo   1. 请先确认系统托盘中的 Ollama 已运行；未运行可在本窗口执行: ollama serve
echo   2. 再执行: ollama run 模型名   （模型过大或内存不足仍会失败）
echo   3. 若仍报 Memory allocation failed，请换更小模型或关闭其它占内存程序
echo.
cmd /k
