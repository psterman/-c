# Shim -> hybrid/Invoke-HybridManualProbe.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "hybrid/Invoke-HybridManualProbe.ps1" -ArgumentList $args
exit $LASTEXITCODE