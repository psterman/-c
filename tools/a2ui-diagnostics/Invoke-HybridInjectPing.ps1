# Shim -> hybrid/Invoke-HybridInjectPing.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Invoke-HybridInjectPing.ps1" -ArgumentList $args
exit $LASTEXITCODE