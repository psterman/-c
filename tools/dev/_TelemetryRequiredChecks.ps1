$script:TelemetryRequiredChecks = @(
    @{ Scope = "surface"; Action = "config_webview_open" },
    @{ Scope = "surface"; Action = "config_webview_close" },
    @{ Scope = "surface"; Action = "search_center_open" },
    @{ Scope = "surface"; Action = "search_center_close" },
    @{ Scope = "surface"; Action = "clipboard_panel_open" },
    @{ Scope = "surface"; Action = "clipboard_panel_close" },
    @{ Scope = "surface"; Action = "command_palette_open" },
    @{ Scope = "surface"; Action = "command_palette_close" },
    @{ Scope = "surface"; Action = "floating_toolbar_open" },
    @{ Scope = "surface"; Action = "floating_toolbar_close" },
    @{ Scope = "surface"; Action = "prompt_quick_pad_open" },
    @{ Scope = "surface"; Action = "prompt_quick_pad_close" },
    @{ Scope = "surface"; Action = "chord_pad_open" },
    @{ Scope = "surface"; Action = "chord_pad_close" },
    @{ Scope = "cmd"; Action = "ch_c" },
    @{ Scope = "cmd"; Action = "cmd_execute" },
    @{ Scope = "cmd"; Action = "cmd_success" },
    @{ Scope = "llm"; Action = "request_start" },
    @{ Scope = "health"; Action = "health_snapshot_result" },
    @{ Scope = "migration"; Action = "export" },
    @{ Scope = "migration"; Action = "preview" },
    @{ Scope = "migration"; Action = "import" },
    @{ Scope = "diagnostics"; Action = "export_bundle" },
    @{ Scope = "diagnostics"; Action = "copy_trace_clipboard" },
    @{ Scope = "health"; Action = "update_check_done" }
)

function Get-TelemetryActionCount {
    param(
        [object]$Doc,
        [string]$Scope,
        [string]$Action
    )
    try {
        if ($null -eq $Doc -or -not $Doc.scopes) { return 0 }
        $scopeObj = $Doc.scopes.$Scope
        if ($null -eq $scopeObj -or -not $scopeObj.actions) { return 0 }
        $actObj = $scopeObj.actions.$Action
        if ($null -eq $actObj -or $null -eq $actObj.count) { return 0 }
        return [int]$actObj.count
    } catch {
        return 0
    }
}

function Get-TelemetryDoc {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Get-TelemetryMissingRequired {
    param(
        [object]$Doc,
        [array]$Checks = $script:TelemetryRequiredChecks
    )
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($c in $Checks) {
        $cnt = Get-TelemetryActionCount -Doc $Doc -Scope $c.Scope -Action $c.Action
        if ($cnt -le 0) {
            $missing.Add("$($c.Scope).$($c.Action)")
        }
    }
    return ,$missing.ToArray()
}

function Wait-TelemetryRequiredReady {
    param(
        [string]$TelemetryPath,
        [int]$PollSec = 90,
        [int]$IntervalSec = 2,
        [array]$Checks = $script:TelemetryRequiredChecks
    )
    $started = Get-Date
    $deadline = $started.AddSeconds($PollSec)
    $lastMissing = @()
    while ((Get-Date) -lt $deadline) {
        $doc = Get-TelemetryDoc -Path $TelemetryPath
        if ($null -ne $doc) {
            $lastMissing = Get-TelemetryMissingRequired -Doc $doc -Checks $Checks
            if ($lastMissing.Count -eq 0) {
                $elapsed = [int]((Get-Date) - $started).TotalSeconds
                Write-Host "telemetry_poll=PASS satisfied=$($Checks.Count) elapsed_sec=$elapsed"
                return $true
            }
        }
        Start-Sleep -Seconds $IntervalSec
    }
    $missingText = if ($lastMissing.Count -gt 0) { $lastMissing -join ", " } else { "telemetry_unreadable" }
    Write-Host "telemetry_poll=TIMEOUT poll_sec=$PollSec missing=$missingText"
    return $false
}
