# Shim -> memory/capture-memory-baseline.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "memory/capture-memory-baseline.ps1" -ArgumentList $args
exit $LASTEXITCODE