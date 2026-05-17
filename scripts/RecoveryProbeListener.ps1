param([int]$Port = 19191)

$ErrorActionPreference = "Stop"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $resp = $ctx.Response
        $buf = [System.Text.Encoding]::UTF8.GetBytes("ok")
        $resp.StatusCode = 200
        $resp.ContentType = "text/plain; charset=utf-8"
        $resp.ContentLength64 = $buf.Length
        $resp.OutputStream.Write($buf, 0, $buf.Length)
        $resp.OutputStream.Close()
    }
} finally {
    try { $listener.Stop() } catch {}
    try { $listener.Close() } catch {}
}
