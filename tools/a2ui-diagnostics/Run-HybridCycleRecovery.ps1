# Shim -> hybrid/Run-HybridCycleRecovery.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridCycleRecovery.ps1" -ArgumentList $args
exit $LASTEXITCODE