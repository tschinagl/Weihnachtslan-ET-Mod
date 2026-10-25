[CmdletBinding()]
param([ValidateRange(1024, 65535)][int]$Port = 27980, [ValidateRange(10, 120)][int]$TimeoutSeconds = 40)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$state = Read-ETLabState
$runtime = Join-Path $etlRoot $state.runtimePath
$exe = Join-Path $runtime 'etlded.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Zuerst Build-Mod.ps1 ausfuehren.' }
if (Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue) { throw "UDP-Port $Port ist belegt." }
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$profile = Join-Path $etlRoot "profiles\smoke-$runId"
$modProfile = Join-Path $profile 'etbudget'
$logs = Join-Path $etlRoot 'logs'
New-Item -ItemType Directory -Path $modProfile, $logs -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $etlRoot 'tests\smoke.lua') -Destination (Join-Path $modProfile 'smoke.lua')
$password = [Guid]::NewGuid().ToString('N')
$config = @"
set sv_hostname "ETLab Local Smoke"
set sv_maxclients 8
set sv_pure 1
set sv_advert 0
set sv_allowDownload 0
set sv_wwwDownload 0
set rconPassword "$password"
set g_gametype 2
set g_warmup 0
set g_doWarmup 0
set g_log "smoke-game.log"
set g_logSync 1
set omnibot_enable 0
set g_luaModuleList ""
set lua_modules "smoke.lua"
map oasis
"@
[IO.File]::WriteAllText((Join-Path $modProfile 'smoke.cfg'), ($config -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))
$etlArgs = @('+set', 'dedicated', '1', '+set', 'net_enabled', '1', '+set', 'net_ip', '127.0.0.1',
    '+set', 'net_port', "$Port", '+set', 'sv_advert', '0', '+set', 'fs_basepath', ('"' + $runtime + '"'),
    '+set', 'fs_homepath', ('"' + $profile + '"'), '+set', 'fs_game', 'etbudget',
    '+set', 'logfile', '2', '+exec', 'smoke.cfg')
function Invoke-LocalRcon {
    param([string]$Command)
    $udp = New-Object Net.Sockets.UdpClient
    try {
        $udp.Client.ReceiveTimeout = 350
        $udp.Connect('127.0.0.1', $Port)
        $payload = [byte[]](@(255, 255, 255, 255) + [Text.Encoding]::ASCII.GetBytes("rcon $password $Command"))
        [void]$udp.Send($payload, $payload.Length)
        $reply = New-Object Text.StringBuilder
        $sender = New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0)
        while ($true) {
            try { $data = $udp.Receive([ref]$sender) } catch [Net.Sockets.SocketException] { break }
            [void]$reply.Append([Text.Encoding]::UTF8.GetString($data, 4, $data.Length - 4))
        }
        return $reply.ToString()
    } finally { $udp.Dispose() }
}
$server = $null
$passed = $false
try {
    $server = Start-Process -FilePath $exe -ArgumentList $etlArgs -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $console = Join-Path $modProfile 'etconsole.log'
    do {
        Start-Sleep -Milliseconds 500
        $server.Refresh()
        if ($server.HasExited) { throw "Server vorzeitig beendet (Exit $($server.ExitCode)); Profil: $profile" }
        $logText = if (Test-Path -LiteralPath $console) { Get-Content -LiteralPath $console -Encoding UTF8 -Raw } else { '' }
        if ($logText -match 'ETLAB_SMOKE_FRAMES_OK') { break }
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($logText -notmatch 'ETLAB_SMOKE_INIT_OK' -or $logText -notmatch 'ETLAB_SMOKE_FRAMES_OK') { throw "Lua-/Map-Smoke nicht erfolgreich; Log: $console" }
    $plainLog = $logText -replace '\^[0-9]', ''
    if ($plainLog -match '(?im)Lua.*(?:error|failed)|VM_Create.*failed|Sys_Error|ERROR No .*?(?:script_multiplayer|tracemap).*? found') { throw "Laufzeitfehler; Log: $console" }
    $endpoints = @(Get-NetUDPEndpoint -OwningProcess $server.Id -ErrorAction Stop)
    if (-not ($endpoints | Where-Object { $_.LocalAddress -eq '127.0.0.1' -and $_.LocalPort -eq $Port })) { throw 'Erwarteter Loopback-Socket fehlt.' }
    if ($endpoints | Where-Object { $_.LocalAddress -ne '127.0.0.1' }) { throw 'Unerwarteter Netzwerk-Socket am Testserver.' }
    $status = Invoke-LocalRcon 'status'
    if ($status -notmatch 'map\s*:\s+oasis') { throw "RCON liefert nicht die erwartete Map: $status" }
    $status | Out-File -LiteralPath (Join-Path $logs "smoke-$runId-rcon.log") -Encoding utf8
    [void](Invoke-LocalRcon 'quit')
    if (-not $server.WaitForExit(5000)) { throw 'Server hat quit nicht rechtzeitig abgeschlossen.' }
    if ($server.ExitCode -ne 0) { throw ('Server-Exitcode: ' + $server.ExitCode) }
    $passed = $true
    Write-Host 'PASS: offizielle Release-Engine, Game-Mod, oasis, Lua-Init + 20 Frames, Loopback-Bindung, RCON status und sauberer Exit.'
} finally {
    if ($server -and -not $server.HasExited) {
        [void](Invoke-LocalRcon 'quit')
        if (-not $server.WaitForExit(5000)) { Stop-Process -Id $server.Id -ErrorAction SilentlyContinue }
    }
    $record = [ordered]@{
        passed = $passed; time = [DateTimeOffset]::Now.ToString('o'); profile = $profile; port = $Port
        executable = $exe; executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
        sourceCommit = (& git -C (Join-Path $etlRoot $state.sourcePath) rev-parse HEAD)
        scope = 'Dedicated server, map, Lua hooks, RCON; no connected player or rendered client'
    }
    $record | ConvertTo-Json | Out-File -LiteralPath (Join-Path $logs "smoke-$runId.json") -Encoding utf8
}
