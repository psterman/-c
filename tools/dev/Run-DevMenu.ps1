param(
    [string]$Root = "",
    [ValidateSet("", "required-fail", "optional-fail")]
    [string]$SmokeTest = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1", "..\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch { }

$ErrorActionPreference = "Continue"
$ciDir = Join-Path $Root "tools\ci"
$htmlDir = Join-Path $Root "html"
$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Nmer DevMenu — 混栈治理本地入口"
Write-Host "  手册: docs/stack-governance.md"
Write-Host "  Tier: required | optional | skip-if-missing"
Write-Host "========================================"
Write-Host ""

$script:Results = New-Object System.Collections.Generic.List[object]

function Invoke-DevMenuStep {
    param(
        [string]$Name,
        [ValidateSet("required", "optional", "skip-if-missing")]
        [string]$Tier,
        [string]$Command = "",
        [string[]]$Args = @(),
        [string]$WorkingDirectory = "",
        [string]$SkipReason = "",
        [scriptblock]$TestSkip = $null,
        [int]$SmokeExitCode = -1
    )

    Write-Host "---- $Name ($Tier) ----"

    if ($SmokeTest -ne "" -and $SmokeExitCode -ge 0) {
        $code = $SmokeExitCode
        $detail = "smoke injected exit=$code"
        Write-Host $detail
        $status = if ($code -eq 0) { "OK" } else { "FAILED" }
        $script:Results.Add([pscustomobject]@{
                Name   = $Name
                Tier   = $Tier
                Status = $status
                Code   = $code
                Detail = $detail
            })
        return
    }

    if ($TestSkip) {
        try {
            if (& $TestSkip) {
                Write-Host "[SKIP] $SkipReason"
                $script:Results.Add([pscustomobject]@{
                        Name   = $Name
                        Tier   = $Tier
                        Status = "SKIP"
                        Code   = -1
                        Detail = $SkipReason
                    })
                return
            }
        } catch {
        }
    }

    if (-not $Command) {
        $msg = "missing command"
        Write-Host "[SKIP] $msg"
        $script:Results.Add([pscustomobject]@{
                Name   = $Name
                Tier   = $Tier
                Status = "SKIP"
                Code   = -1
                Detail = $msg
            })
        return
    }
    $isPs1 = $Command -match '\.ps1$'
    $isPathExe = $Command -match '[/\\]'
    if ($isPs1 -or $isPathExe) {
        if (-not (Test-Path -LiteralPath $Command)) {
            $msg = "missing command: $Command"
            Write-Host "[SKIP] $msg"
            $script:Results.Add([pscustomobject]@{
                    Name   = $Name
                    Tier   = $Tier
                    Status = "SKIP"
                    Code   = -1
                    Detail = $msg
                })
            return
        }
    } elseif (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        $msg = "missing executable: $Command"
        Write-Host "[SKIP] $msg"
        $script:Results.Add([pscustomobject]@{
                Name   = $Name
                Tier   = $Tier
                Status = "SKIP"
                Code   = -1
                Detail = $msg
            })
        return
    }

    $cwd = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path $Command -Parent }
    $code = 0
    $logPath = Join-Path $reportDir ("devmenu_" + ($Name -replace '[^\w]', '_') + ".log")
    try {
        Push-Location $cwd
        & $Command @Args 2>&1 | Tee-Object -FilePath $logPath | ForEach-Object { Write-Host $_ }
        if ($null -ne $LASTEXITCODE) { $code = [int]$LASTEXITCODE }
    } catch {
        Write-Host "error=$($_.Exception.Message)"
        $code = 1
    } finally {
        Pop-Location
    }

    $status = if ($code -eq 0) { "OK" } else { "FAILED" }
    $detail = if ($code -ne 0) { "exit=$code see $logPath" } else { "" }
    Write-Host "[$status] exit=$code"
    $script:Results.Add([pscustomobject]@{
            Name   = $Name
            Tier   = $Tier
            Status = $status
            Code   = $code
            Detail = $detail
        })
}

function Resolve-NodeExe {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
            (Join-Path ${env:ProgramFiles} "nodejs\node.exe"),
            (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe")
        )) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return $null
}

function Test-NodeAvailable {
    return [bool](Resolve-NodeExe)
}

if ($SmokeTest -eq "required-fail") {
    Invoke-DevMenuStep -Name "MinimalGate" -Tier "required" -SmokeExitCode 1
    Invoke-DevMenuStep -Name "Frozen Path Policy" -Tier "optional" -SmokeExitCode 0
    Invoke-DevMenuStep -Name "SearchCore Lifecycle" -Tier "optional" -SmokeExitCode 0
} elseif ($SmokeTest -eq "optional-fail") {
    Invoke-DevMenuStep -Name "MinimalGate" -Tier "required" -SmokeExitCode 0
    Invoke-DevMenuStep -Name "Frozen Path Policy" -Tier "optional" -SmokeExitCode 0
    Invoke-DevMenuStep -Name "SearchCore Lifecycle" -Tier "optional" -SmokeExitCode 1
} else {
    Invoke-DevMenuStep -Name "MinimalGate" -Tier "required" `
        -Command (Join-Path $ciDir "Run-MinimalGate.ps1") `
        -Args @("-Root", $Root, "-Strict")

    Invoke-DevMenuStep -Name "Frozen Path Policy" -Tier "optional" `
        -Command (Join-Path $ciDir "Validate-FrozenPathPolicy.ps1") `
        -Args @("-Root", $Root)

    Invoke-DevMenuStep -Name "SearchCore Lifecycle" -Tier "optional" `
        -Command (Join-Path $ciDir "Run-SearchCoreLifecycleSuite.ps1") `
        -Args @("-Root", $Root)
}

# ---- Summary ----
$ok = @($script:Results | Where-Object { $_.Status -eq "OK" }).Count
$skip = @($script:Results | Where-Object { $_.Status -eq "SKIP" }).Count
$failed = @($script:Results | Where-Object { $_.Status -eq "FAILED" }).Count
$requiredFailed = @($script:Results | Where-Object { $_.Tier -eq "required" -and $_.Status -eq "FAILED" })

Write-Host ""
Write-Host "======== DevMenu Summary ========"
foreach ($r in $script:Results) {
    $tag = "[$($r.Status)]".PadRight(8)
    $line = "$tag $($r.Name) ($($r.Tier))"
    if ($r.Detail) { $line += " — $($r.Detail)" }
    Write-Host $line
}
Write-Host "---------------------------------"
Write-Host "OK=$ok  SKIP=$skip  FAILED=$failed"

$summaryExit = if ($requiredFailed.Count -gt 0) { 1 } else { 0 }
if ($summaryExit -eq 1) {
    $names = ($requiredFailed | ForEach-Object { $_.Name }) -join ", "
    Write-Host "summary exit=1  (required 失败: $names)"
} else {
    Write-Host "summary exit=0  (required 全部 OK；optional 失败不抬高退出码)"
}
Write-Host "================================="
Write-Host ""
Write-Host "请看上方逐项状态；不要只看 exit 码。optional 失败会显示 [FAILED] 但 summary 可为 0."

$summaryPath = Join-Path $reportDir "devmenu_summary.txt"
$summaryLines = @("OK=$ok SKIP=$skip FAILED=$failed summary_exit=$summaryExit")
$script:Results | ForEach-Object {
    $summaryLines += "$($_.Status)`t$($_.Name)`t$($_.Tier)`t$($_.Detail)"
}
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "summaryReport=$summaryPath"

exit $summaryExit
