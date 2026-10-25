[CmdletBinding()]
param(
    [ValidateSet('Release', 'RelWithDebInfo', 'Debug')]
    [string]$Configuration = 'Release',
    [ValidateRange(1, 32)][int]$Jobs = 8,
    [switch]$Locked,
    [switch]$OnlyIfNeeded,
    [switch]$ConfigureOnly
)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/Prepare-Mod.ps1" -Locked:$Locked
. "$PSScriptRoot/Common.ps1"
$state = Read-ETLabState
$etlSource = Join-Path $etlRoot $state.sourcePath
$etlBuild = Join-Path $etlSource 'build'
$etlRuntime = Join-Path $etlRoot $state.runtimePath
$etlLogs = Join-Path $etlRoot 'logs'
New-Item -ItemType Directory -Path $etlLogs -Force | Out-Null
$fingerprintFile = Join-Path $etlLogs 'build-fingerprint.json'
$inputFiles = @(Get-ChildItem -Path (Join-Path $etlRoot 'scripts'), (Join-Path $etlRoot 'tests'), (Join-Path $etlRoot 'mod') -File -Recurse)
$inputFiles += Get-Item -LiteralPath (Join-Path $etlRoot 'release.lock.json')
$fingerprint = $Configuration + ':' + (($inputFiles | Sort-Object FullName | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join ':')
if ($OnlyIfNeeded -and (Test-Path -LiteralPath $fingerprintFile)) {
    $previous = Get-Content -LiteralPath $fingerprintFile -Encoding UTF8 -Raw | ConvertFrom-Json
    $valid = $previous.input -eq $fingerprint
    foreach ($item in $previous.outputs) {
        $file = Join-Path $etlRuntime ('etbudget/' + $item.name)
        if (-not (Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $item.sha256) { $valid = $false }
    }
    if ($valid) { Write-Host 'Mod-Build ist aktuell und seine Dateien sind unveraendert.'; return }
}
$running = @(Get-Process etl,etlded -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($etlRuntime, [StringComparison]::OrdinalIgnoreCase) })
if ($running.Count) { throw 'ETLab laeuft noch. Vor dem Build bitte Spiel/Server schliessen.' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -version '[17.0,18.0)' -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw 'Visual Studio 2022 mit MSVC x64/x86 fehlt. Siehe docs/build-und-start.md.' }
$cmake = Join-Path ($vsPath | Select-Object -First 1) 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
if (-not (Test-Path -LiteralPath $cmake)) { throw 'CMake-Komponente von Visual Studio fehlt.' }
function Invoke-CMakeLogged {
    param([string[]]$Arguments, [string]$LogName)
    $logFile = Join-Path $etlLogs $LogName
    [IO.File]::WriteAllText($logFile, '', (New-Object Text.UTF8Encoding($true)))
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $cmake @Arguments 2>&1 | ForEach-Object {
            $line = $_.ToString()
            Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
            Write-Host $line
        }
        $cmakeExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($cmakeExit -ne 0) { throw "CMake fehlgeschlagen: $LogName (Exit $cmakeExit)" }
}
# Only game modules are built. Engine executables come from the official release archive.
$configureArgs = @('-S', $etlSource, '-B', $etlBuild, '-G', 'Visual Studio 17 2022', '-A', 'x64',
    '-DCROSS_COMPILE32=OFF', '-DBUNDLED_LIBS=ON', '-DMODNAME=etbudget',
    '-DBUILD_CLIENT=OFF', '-DBUILD_SERVER=OFF', '-DBUILD_MOD=ON',
    "-DCMAKE_INSTALL_PREFIX=$($etlRuntime.Replace('\', '/'))",
    '-DINSTALL_EXTRA=OFF', '-DFEATURE_AUTOUPDATE=OFF', '-DFEATURE_AUTH=OFF',
    '-DFEATURE_TRACKER=OFF', '-DFEATURE_IRC_CLIENT=OFF', '-DFEATURE_IRC_SERVER=OFF',
    '-DFEATURE_CURL=OFF', '-DFEATURE_SSL=OFF', '-DFEATURE_LUA=ON', '-DETLAB_BUILD_TESTS=ON')
Invoke-CMakeLogged -Arguments $configureArgs -LogName 'configure.log'
if ($ConfigureOnly) { return }
$buildArgs = @('--build', $etlBuild, '--config', $Configuration, '--parallel', "$Jobs")
$buildArgs += @('--target', 'qagame', 'cgame', 'ui', 'tvgame', 'mod_pk3', 'etlab_loadout_tests')
Invoke-CMakeLogged -Arguments $buildArgs -LogName 'build.log'
$ctest = Join-Path (Split-Path $cmake -Parent) 'ctest.exe'
& $ctest --test-dir $etlBuild -C $Configuration --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'ETLab gameplay regression tests failed.' }
$modOutput = Join-Path $etlBuild 'etbudget'
$modRuntime = Join-Path $etlRuntime 'etbudget'
New-Item -ItemType Directory -Path $modRuntime -Force | Out-Null
$modFiles = @(Get-ChildItem -LiteralPath $modOutput -File | Where-Object { $_.Extension -in @('.dll', '.pk3') })
$manifestPath = Join-Path $etlLogs 'staged-mod-manifest.json'
$previousNames = @()
if (Test-Path -LiteralPath $manifestPath) {
    $previousManifest = Get-Content -LiteralPath $manifestPath -Encoding UTF8 -Raw | ConvertFrom-Json
    $previousNames = @($previousManifest.files)
}
foreach ($oldPak in (Get-ChildItem -LiteralPath $modRuntime -Filter 'etbudget_*.pk3' -File)) {
    if ($oldPak.Name -in $modFiles.Name) { continue }
    if ($oldPak.Name -notin $previousNames) { throw "Nicht verwaltetes altes Paket kann den Build ueberdecken: $($oldPak.FullName). Bitte manuell klaeren." }
    $archive = Join-Path $etlRoot ('archive\mod-staging\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $archive -Force | Out-Null
    # Only individual manifest-owned files in the fixed runtime mod directory are moved.
    Move-Item -LiteralPath $oldPak.FullName -Destination (Join-Path $archive $oldPak.Name)
}
# Stage all native mod binaries consistently, including loose cgame/ui for debugging.
$modFiles | Copy-Item -Destination $modRuntime -Force
[ordered]@{ configuration = $Configuration; files = @($modFiles.Name); sourceCommit = (& git -C $etlSource rev-parse HEAD) } |
    ConvertTo-Json | Out-File -LiteralPath $manifestPath -Encoding utf8
Write-Host "Build und Staging fertig: $etlRuntime"

$outputs = @($modFiles | ForEach-Object { [ordered]@{ name = $_.Name; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } })
Write-ETLabJson $fingerprintFile ([ordered]@{ input = $fingerprint; outputs = $outputs })
