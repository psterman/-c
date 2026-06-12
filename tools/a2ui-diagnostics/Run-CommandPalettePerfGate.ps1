# Shim -> command-palette/Run-CommandPalettePerfGate.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "command-palette/Run-CommandPalettePerfGate.ps1" -ArgumentList $args
exit $LASTEXITCODE