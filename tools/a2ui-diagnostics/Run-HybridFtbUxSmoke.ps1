# Shim -> hybrid/Run-HybridFtbUxSmoke.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridFtbUxSmoke.ps1" -ArgumentList $args
exit $LASTEXITCODE