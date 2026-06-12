# Shim -> hybrid/Run-HybridSignoff.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridSignoff.ps1" -ArgumentList $args
exit $LASTEXITCODE