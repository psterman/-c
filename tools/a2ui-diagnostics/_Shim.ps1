param(
    [Parameter(Mandatory = $true)][string]$RelativeScript,
    [object[]]$ArgumentList = @()
)
. (Join-Path $PSScriptRoot "_DiagRoot.ps1")
$target = Join-DiagScript -RelativePath $RelativeScript -From $PSScriptRoot
if (-not (Test-Path -LiteralPath $target)) {
    throw "诊断脚本不存在: $target"
}
if ($ArgumentList -and $ArgumentList.Count -gt 0) {
    & $target @ArgumentList
} else {
    & $target
}
exit $LASTEXITCODE
