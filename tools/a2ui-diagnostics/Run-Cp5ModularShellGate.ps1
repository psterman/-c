# Shim -> command-palette/Run-Cp5ModularShellGate.ps1
& (Join-Path $PSScriptRoot "command-palette\Run-Cp5ModularShellGate.ps1") @args
exit $LASTEXITCODE
