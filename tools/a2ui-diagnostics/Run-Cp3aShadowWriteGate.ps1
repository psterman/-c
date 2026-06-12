# Shim -> command-palette/Run-Cp3aShadowWriteGate.ps1
& (Join-Path $PSScriptRoot "command-palette\Run-Cp3aShadowWriteGate.ps1") @args
exit $LASTEXITCODE
