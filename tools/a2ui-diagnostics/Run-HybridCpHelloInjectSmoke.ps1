# Shim -> hybrid/Run-HybridCpHelloInjectSmoke.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Run-HybridCpHelloInjectSmoke.ps1" -ArgumentList $args
exit $LASTEXITCODE