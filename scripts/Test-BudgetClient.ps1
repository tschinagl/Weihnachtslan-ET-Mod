[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
. "$PSScriptRoot/Hidden-TestClient.ps1"
$inputDesktopBefore = [ETBudget.HiddenClient]::InputDesktopName()
$state = Read-ETLabState
$runtime = Join-Path $etlRoot $state.runtimePath
$profile = Join-Path $etlRoot ('profiles\budget-smoke-' + [Guid]::NewGuid().ToString('N'))
$modProfile = Join-Path $profile 'etbudget'
if (Get-NetUDPEndpoint -LocalPort 27980 -ErrorAction SilentlyContinue) { throw 'Budget test port 27980 is busy.' }
New-Item -ItemType Directory -Path $modProfile -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $etlRoot 'tests\budget-runtime.lua') -Destination (Join-Path $modProfile 'budget-runtime.lua')
$config = @"
set name BudgetTest
set sv_hostname "ETBudget Local Test"
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
set g_userAxisRespawnTime 1
set g_userAlliedRespawnTime 1
set g_heavyWeaponRestriction 100
set g_luaModuleList ""
set lua_modules "budget-runtime.lua"
set g_log "budget-test.log"
set g_logSync 1
set g_etlabPractice 0
set cg_budgetLoadout 19
set cg_autoAction 0
devmap oasis
wait 180
map_restart 0
wait 60
team r 5 0 0 19
"@
[IO.File]::WriteAllText((Join-Path $modProfile 'budget-test.cfg'), ($config -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))
$etlArgs = @('+set', 'fs_basepath', ('"' + $runtime + '"'), '+set', 'fs_homepath', ('"' + $profile + '"'),
    '+set', 'fs_game', 'etbudget', '+set', 'dedicated', '0', '+set', 'net_enabled', '1',
    '+set', 'net_ip', '127.0.0.1', '+set', 'net_port', '27980', '+set', 'sv_advert', '0',
    '+set', 'cl_autoupdate', '0', '+set', 'com_introplayed', '1', '+set', 'logfile', '2', '+set', 'com_maxfps', '60',
    '+set', 'r_fullscreen', '0', '+set', 'r_mode', '-1', '+set', 'r_customwidth', '1280', '+set', 'r_customheight', '720',
    '+exec', 'budget-test.cfg')
$client = $null
$hiddenClient = $null
try {
    $hiddenClient = Start-HiddenTestClient -Executable (Join-Path $runtime 'etl.exe') -Arguments $etlArgs -Directory $runtime
    $client = $hiddenClient.Process
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while (-not $client.WaitForExit(1000) -and [DateTime]::UtcNow -lt $deadline) { }
    if (-not $client.HasExited) { throw "Budget client timeout; profile: $profile" }
    if ($client.ExitCode -ne 0) { throw "Budget client failed: $($client.ExitCode); profile: $profile" }
    $log = Get-Content -LiteralPath (Join-Path $modProfile 'etconsole.log') -Encoding UTF8 -Raw
    if ($log -notmatch 'ETBUDGET_RUNTIME_PASS' -or $log -match 'ETBUDGET_RUNTIME_FAIL|Lua error') { throw "Budget runtime assertions failed; profile: $profile" }
    $shot = Join-Path $modProfile 'screenshots\etbudget-limbo.jpg'
    if (-not (Test-Path -LiteralPath $shot)) { throw "Limbo screenshot missing: $shot" }
    if ([ETBudget.HiddenClient]::InputDesktopName() -ne $inputDesktopBefore) { throw "Input desktop changed during test." }
    if ($log -notmatch 'Sound disabled') { throw "Sound initialization was not disabled." }
    Write-Output "PASS silent hidden-desktop Budget runtime: $shot"
    Write-ETLabJson (Join-Path $etlRoot 'logs/budget-client.json') ([ordered]@{ passed = $true; desktop = $hiddenClient.DesktopName; inputDesktop = $inputDesktopBefore; soundDisabled = $true; profile = $profile; screenshot = $shot; patchSha256 = $state.patchSha256; engineSha256 = (Get-FileHash -LiteralPath (Join-Path $runtime 'etl.exe') -Algorithm SHA256).Hash })
} finally {
    if ($client -and -not $client.HasExited) {
        if (-not $client.CloseMainWindow() -or -not $client.WaitForExit(5000)) { Stop-Process -Id $client.Id }
    }
    if ($hiddenClient) { $hiddenClient.Dispose() }
}
