# Shim -> hybrid/Run-HybridHubChainSmoke.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridHubChainSmoke.ps1" -ArgumentList $args
exit $LASTEXITCODE