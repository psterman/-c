# Shim -> surface/Diagnose-SurfaceRuntime.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "surface/Diagnose-SurfaceRuntime.ps1" -ArgumentList $args
exit $LASTEXITCODE