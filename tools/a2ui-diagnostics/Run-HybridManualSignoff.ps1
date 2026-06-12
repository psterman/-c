# Shim -> hybrid/Run-HybridManualSignoff.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridManualSignoff.ps1" -ArgumentList $args
exit $LASTEXITCODE