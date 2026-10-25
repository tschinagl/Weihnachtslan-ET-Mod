[CmdletBinding()]
param([switch]$Connect, [ValidateRange(1024, 65535)][int]$Port = 27980)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$state = Read-ETLabState
$runtime = Join-Path $etlRoot $state.runtimePath
$profile = Join-Path $etlRoot 'profiles\client'
$exe = Join-Path $runtime 'etl.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Zuerst Build-Mod.ps1 ausfuehren.' }
New-Item -ItemType Directory -Path $profile -Force | Out-Null
$etlArgs = @('+set', 'fs_basepath', ('"' + $runtime + '"'), '+set', 'fs_homepath', ('"' + $profile + '"'),
    '+set', 'fs_game', 'etbudget', '+set', 'com_introplayed', '1', '+set', 'cl_autoupdate', '0',
    '+set', 'net_enabled', '1')
if ($Connect) { $etlArgs += @('+connect', "127.0.0.1:$Port") }
Start-Process -FilePath $exe -ArgumentList $etlArgs -WorkingDirectory $runtime | Out-Null
