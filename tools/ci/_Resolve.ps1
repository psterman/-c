function Nmer-ResolveProjectRoot {
    param([string]$From = $PSScriptRoot)
    $p = $From
    for ($i = 0; $i -lt 10; $i++) {
        if (Nmer-TestProjectRootMarker -Path $p) {
            return (Resolve-Path -LiteralPath $p).Path
        }
        $next = Split-Path $p -Parent
        if (-not $next -or $next -eq $p) { break }
        $p = $next
    }
    throw "Cannot find project root (modules/ToolsPaths.ahk + main .ahk) from $From"
}

function Nmer-TestProjectRootMarker {
    param([string]$Path)
    $toolsPaths = Join-Path $Path "modules\ToolsPaths.ahk"
    $scwv = Join-Path $Path "modules\SearchCenterWebViewCore.ahk"
    if (-not (Test-Path -LiteralPath $toolsPaths)) { return $false }
    if (-not (Test-Path -LiteralPath $scwv)) { return $false }
    $mainAhk = Get-ChildItem -LiteralPath $Path -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^(VirtualKeyboard|probe_|test_)' } |
        Sort-Object Length -Descending |
        Select-Object -First 1
    return [bool]$mainAhk
}

function Nmer-ResolveMainAhk {
    param([string]$Root)
    $literal = Join-Path $Root "牛马.ahk"
    if (Test-Path -LiteralPath $literal) {
        return (Resolve-Path -LiteralPath $literal).Path
    }
    $mainAhk = Get-ChildItem -LiteralPath $Root -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^(VirtualKeyboard|probe_|test_)' } |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if ($mainAhk) { return $mainAhk.FullName }
    throw "Cannot find main .ahk under $Root"
}

function Nmer-ResolveCiScript {
    param(
        [string]$Root,
        [string]$RelativeName
    )
    foreach ($sub in @("tools\ci", "tools\ci\probes", "scripts")) {
        $candidate = Join-Path $Root (Join-Path $sub $RelativeName)
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return Join-Path $Root "tools\ci\$RelativeName"
}

function Nmer-ReadAhkLaunchChoice {
    param([string]$Root)
    $p = Join-Path $Root "Cache\ahk_launch_choice.txt"
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $m = @{}
    foreach ($line in (Get-Content -LiteralPath $p -Encoding UTF8)) {
        if ($line -match "=") {
            $kv = $line.Split("=", 2)
            $m[$kv[0].Trim()] = $kv[1].Trim()
        }
    }
    if ($m.ContainsKey("exe") -and $m.ContainsKey("mode")) {
        return [pscustomobject]@{ Exe = $m["exe"]; Mode = $m["mode"] }
    }
    return $null
}

function Nmer-InvokeAhkScript {
    param(
        [string]$Exe,
        [string]$ScriptPath,
        [string]$Mode = "plain_with_cwd",
        [string[]]$ExtraArgs = @()
    )
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }
    $ScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
    $wd = Split-Path -Parent $ScriptPath
    $useErrOut = ($Mode -eq "errorstdout" -or $Mode -eq "errorstdout_with_cwd")
    $argList = New-Object System.Collections.Generic.List[string]
    if ($useErrOut) {
        $argList.Add("/ErrorStdOut")
    }
    $argList.Add($ScriptPath)
    foreach ($a in $ExtraArgs) {
        if ($null -ne $a -and "$a" -ne "") {
            $argList.Add([string]$a)
        }
    }
    $errFile = Join-Path $env:TEMP ("nmer_ahk_err_" + [Guid]::NewGuid().ToString("N") + ".txt")
    $proc = Start-Process -FilePath $Exe -ArgumentList $argList.ToArray() -WorkingDirectory $wd `
        -Wait -PassThru -NoNewWindow -RedirectStandardError $errFile
    if (Test-Path -LiteralPath $errFile) {
        $stderr = Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue
        if ($stderr -and $stderr.Trim()) {
            Write-Host ("ahk_stderr_file=" + $errFile)
        } else {
            Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
        }
    }
    if ($null -eq $proc.ExitCode) { return 0 }
    return [int]$proc.ExitCode
}

function Nmer-InvokeSearchCoreProbe {
    param(
        [string]$Root,
        [string]$ProbeRelativeName,
        [string[]]$ExtraArgs = @()
    )
    $choice = Nmer-ReadAhkLaunchChoice -Root $Root
    if ($null -eq $choice -or -not (Test-Path -LiteralPath $choice.Exe)) {
        throw "AHK launch choice missing. Run tools/ci/TryAhkLaunchMatrix.ps1 first."
    }
    $probe = Nmer-ResolveCiScript -Root $Root -RelativeName $ProbeRelativeName
    if (-not (Test-Path -LiteralPath $probe)) {
        throw "Probe not found: $probe"
    }
    return Nmer-InvokeAhkScript -Exe $choice.Exe -ScriptPath $probe -Mode "errorstdout_with_cwd" -ExtraArgs $ExtraArgs
}
