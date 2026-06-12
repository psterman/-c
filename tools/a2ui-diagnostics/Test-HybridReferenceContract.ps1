# Shim -> hybrid/Test-HybridReferenceContract.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Test-HybridReferenceContract.ps1" -ArgumentList $args
exit $LASTEXITCODE
