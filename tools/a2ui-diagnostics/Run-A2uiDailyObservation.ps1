# Shim -> a2ui-rollout/Run-A2uiDailyObservation.ps1
& "$PSScriptRoot\_Shim.ps1" -RelativeScript "a2ui-rollout/Run-A2uiDailyObservation.ps1" -ArgumentList $args
exit $LASTEXITCODE