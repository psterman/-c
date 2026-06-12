# Shim -> memory/Run-MemorySoakTest.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "memory/Run-MemorySoakTest.ps1" -ArgumentList $args
exit $LASTEXITCODE