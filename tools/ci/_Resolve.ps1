function Nmer-ResolveProjectRoot {
    param([string]$From = $PSScriptRoot)
    $p = $From
    for ($i = 0; $i -lt 8; $i++) {
        if (Test-Path (Join-Path $p "牛马.ahk")) {
            return (Resolve-Path $p).Path
        }
        $next = Split-Path $p -Parent
        if (-not $next -or $next -eq $p) { break }
        $p = $next
    }
    throw "Cannot find project root (牛马.ahk) from $From"
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
