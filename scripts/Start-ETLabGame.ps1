[CmdletBinding()]
param([ValidatePattern('^[a-zA-Z0-9_]+$')][string]$Map = 'oasis', [switch]$SmokeTest, [switch]$MineSmoke)
$ErrorActionPreference = 'Stop'
if ($MineSmoke) { $SmokeTest = $true }
. "$PSScriptRoot/Common.ps1"
$state = Read-ETLabState
$runtime = Join-Path $etlRoot $state.runtimePath
$profile = Join-Path $etlRoot 'profiles\play'
if ($SmokeTest) { $profile = Join-Path $etlRoot ('profiles\client-smoke-' + [Guid]::NewGuid().ToString('N')) }
$modProfile = Join-Path $profile 'etbudget'
$exe = Join-Path $runtime 'etl.exe'
foreach ($required in @($exe, (Join-Path $runtime 'etbudget\qagame_mp_x64.dll'), (Join-Path $runtime 'etmain\pak0.pk3'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Spieldatei fehlt: $required. Zuerst Build-Mod.ps1 ausfuehren." }
}
if (Get-NetUDPEndpoint -LocalPort 27980 -ErrorAction SilentlyContinue) { throw 'Port 27980 ist belegt. Den vorhandenen ETLab-Server zuerst mit quit beenden.' }
New-Item -ItemType Directory -Path $modProfile -Force | Out-Null
$firstRun = -not (Test-Path -LiteralPath (Join-Path $modProfile 'etconfig.cfg'))
$config = @"
set sv_hostname "ETBudget - Custom Loadouts"
set sv_advert 0
set sv_pure 1
set sv_allowDownload 0
set sv_wwwDownload 0
set sv_maxclients 8
set omnibot_enable 0
set g_gametype 2
set g_doWarmup 0
set g_warmup 0
set match_minplayers 1
set g_heavyWeaponRestriction 100
set team_maxPanzers -1
set team_maxFlamers -1
set g_luaModuleList ""
set lua_modules ""
set g_log "etlab-play.log"
set g_logSync 1
set g_etlabPractice 0
bind F6 "etlab_targets"
map $Map
"@
if ($firstRun) {
    $config = "set name Player`r`nset r_fullscreen 0`r`nset r_mode -1`r`nset r_customwidth 1280`r`nset r_customheight 720`r`n" + $config
}
if ($SmokeTest) {
    $config = "set g_userAxisRespawnTime 1`r`nset g_userAlliedRespawnTime 1`r`n" + $config
    $config += "`r`nwait 180`r`nmap_restart 0`r`nwait 60`r`nteam r 0 5 0`r`nwait 240`r`nweaponbank 2`r`nwait 90`r`nscreenshotJPEG etlab-akimbo`r`nwait 15`r`nweaponbank 5`r`nwait 60`r`nscreenshotJPEG etlab-pliers`r`nwait 15`r`nquit`r`n"
}
if ($MineSmoke) {
    Copy-Item -LiteralPath (Join-Path $etlRoot 'tests\mines-runtime.lua') -Destination (Join-Path $modProfile 'mines-runtime.lua') -Force
    $config = $config.Substring(0, $config.IndexOf("`r`nwait 180"))
    $config = $config.Replace('set lua_modules ""', 'set lua_modules "mines-runtime.lua"').Replace("map $Map", "devmap $Map")
    $config += "`r`nwait 180`r`nmap_restart 0`r`nwait 60`r`nteam r 0 5 0`r`n"
}
[IO.File]::WriteAllText((Join-Path $modProfile 'etlab-play.cfg'), ($config -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))
$etlArgs = @('+set', 'fs_basepath', ('"' + $runtime + '"'), '+set', 'fs_homepath', ('"' + $profile + '"'),
    '+set', 'fs_game', 'etbudget', '+set', 'dedicated', '0', '+set', 'net_enabled', '1',
    '+set', 'net_ip', '127.0.0.1', '+set', 'net_port', '27980', '+set', 'sv_advert', '0',
    '+set', 'cl_autoupdate', '0', '+set', 'com_introplayed', '1', '+set', 'logfile', '2', '+exec', 'etlab-play.cfg')
if ($firstRun) { $etlArgs += @('+set', 'r_fullscreen', '0', '+set', 'r_mode', '-1', '+set', 'r_customwidth', '1280', '+set', 'r_customheight', '720') }
if ($SmokeTest) {
    $etlArgs += @('+set', 'com_maxfps', '60')
    . "$PSScriptRoot/Hidden-TestClient.ps1"
    $hiddenClient = Start-HiddenTestClient -Executable $exe -Arguments $etlArgs -Directory $runtime
    $client = $hiddenClient.Process
    $deadline = [DateTime]::UtcNow.AddSeconds($(if ($MineSmoke) { 180 } else { 90 }))
    while (-not $client.WaitForExit(1000) -and [DateTime]::UtcNow -lt $deadline) { }
    if (-not $client.HasExited) {
        if (-not $client.CloseMainWindow() -or -not $client.WaitForExit(5000)) { Stop-Process -Id $client.Id }
        $hiddenClient.Dispose()
        throw "Client-Smoke Timeout; Profil: $profile"
    }
    $hiddenClient.Dispose()
    if ($client.ExitCode -ne 0) { throw "Client-Smoke Exitcode $($client.ExitCode); Profil: $profile" }
    $log = Get-Content -LiteralPath (Join-Path $modProfile 'etconsole.log') -Encoding UTF8 -Raw
    $gameLog = Get-Content -LiteralPath (Join-Path $modProfile 'etlab-play.log') -Encoding UTF8 -Raw
    $screenshot = Join-Path $modProfile 'screenshots\etlab-akimbo.jpg'
    if ($MineSmoke) {
        $screenshot = Join-Path $modProfile 'screenshots\etlab-mines-spotted.jpg'
        if ($log -notmatch 'ETLAB_MINES_RUNTIME_PASS' -or $log -match 'ETLAB_MINES_RUNTIME_FAIL|Lua error') { throw "Minen-Laufzeittest fehlgeschlagen; Profil: $profile" }
    }
    if ($gameLog -notmatch 'ClientBegin: 0' -or $log -notmatch 'Initializing etbudget cgame' -or -not (Test-Path -LiteralPath $screenshot)) { throw "Client-Smoke unvollstaendig; Profil: $profile" }
    Write-Output "PASS Client-Smoke: $screenshot"
    return
}
# This launcher is invoked by the player to open the interactive game window.
Start-Process -FilePath $exe -ArgumentList $etlArgs -WorkingDirectory $runtime | Out-Null
