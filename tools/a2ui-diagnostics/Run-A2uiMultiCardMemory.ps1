# Shim -> memory/Run-A2uiMultiCardMemory.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "memory/Run-A2uiMultiCardMemory.ps1" -ArgumentList $args
exit $LASTEXITCODE
