# Shim -> hybrid/Run-HybridCpSignoffPipeline.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridCpSignoffPipeline.ps1" -ArgumentList $args
exit $LASTEXITCODE
