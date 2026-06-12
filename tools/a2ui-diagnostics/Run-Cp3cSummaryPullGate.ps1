# Shim -> command-palette/Run-Cp3cSummaryPullGate.ps1
& (Join-Path $PSScriptRoot "command-palette\Run-Cp3cSummaryPullGate.ps1") @args
exit $LASTEXITCODE
