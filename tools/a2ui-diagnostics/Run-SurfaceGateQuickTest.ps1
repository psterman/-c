# Shim -> surface/Run-SurfaceGateQuickTest.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "surface/Run-SurfaceGateQuickTest.ps1" -ArgumentList $args
exit $LASTEXITCODE