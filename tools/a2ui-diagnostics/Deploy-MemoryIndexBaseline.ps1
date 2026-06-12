# Shim -> memory/Deploy-MemoryIndexBaseline.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "memory/Deploy-MemoryIndexBaseline.ps1" -ArgumentList $args
exit $LASTEXITCODE