[CmdletBinding()]
param([ValidatePattern('^[a-zA-Z0-9_]+$')][string]$Map = 'oasis', [ValidateRange(1024, 65535)][int]$Port = 27980)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$state = Read-ETLabState
$runtime = Join-Path $etlRoot $state.runtimePath
$profile = Join-Path $etlRoot 'profiles\server'
$exe = Join-Path $runtime 'etlded.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Zuerst Build-Mod.ps1 ausfuehren.' }
if (Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue) { throw "UDP-Port $Port ist belegt." }
New-Item -ItemType Directory -Path $profile -Force | Out-Null
Write-Host "Lokaler ETLab-Server: 127.0.0.1:$Port, Map $Map. Beenden mit quit in der Serverkonsole."
& $exe +set dedicated 1 +set net_enabled 1 +set net_ip 127.0.0.1 +set net_port $Port +set sv_advert 0 +set fs_basepath $runtime +set fs_homepath $profile +set fs_game etlab +set sv_hostname 'ETLab Local Development' +set sv_allowDownload 0 +set sv_wwwDownload 0 +set logfile 2 +set omnibot_enable 0 +set g_gametype 2 +map $Map
