# Shim -> memory/Run-ScWebEmbedProbe.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "memory/Run-ScWebEmbedProbe.ps1" -ArgumentList $args
exit $LASTEXITCODE
