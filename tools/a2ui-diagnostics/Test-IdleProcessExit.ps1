# Shim -> memory/Test-IdleProcessExit.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "memory/Test-IdleProcessExit.ps1" -ArgumentList $args
exit $LASTEXITCODE