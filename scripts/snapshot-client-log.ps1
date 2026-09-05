<#
Mid-session client log snapshot for pz-zombie-factions.

The client's DebugLog.txt is a rolling buffer capped in place at roughly
4.3MB (observed): once a live session's log volume crosses that line, the
file silently drops its own oldest lines to make room for new ones. There is
no rotated backup to recover from afterward -- the content is gone by the
time the session ends, well before posttest-cleanup.ps1 ever runs.

Run this script BETWEEN distinct sub-tests in one long session (e.g. right
after a small-scale posture matrix, before spawning a mass-combat crowd) to
preserve that phase's detail before later volume can push it out. It does
not stop, clear, or otherwise disturb the running client or server -- safe
to run as many times as needed during a session.

Each run produces its own timestamped zip in the repo's gitignored Logs/
folder, alongside the pretest/posttest zips.
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ZomboidDir = Join-Path $env:USERPROFILE 'Zomboid'
$LocalLogsDir = Join-Path $ZomboidDir 'Logs'
$LocalConsole = Join-Path $ZomboidDir 'console.txt'
$RepoLogsDir = Join-Path $RepoRoot 'Logs'
$Stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

New-Item -ItemType Directory -Force -Path $RepoLogsDir | Out-Null

Write-Host "== Snapshotting live client logs (session continues undisturbed) =="
$stage = Join-Path $env:TEMP "pzclient_snapshot_$Stamp"
New-Item -ItemType Directory -Force -Path $stage | Out-Null
if (Test-Path $LocalLogsDir) { Copy-Item "$LocalLogsDir\*" $stage -Recurse -Force }
if (Test-Path $LocalConsole) { Copy-Item $LocalConsole $stage -Force }

$zip = Join-Path $RepoLogsDir "client-snapshot_$Stamp.zip"
Compress-Archive -Path "$stage\*" -DestinationPath $zip -Force
Remove-Item $stage -Recurse -Force

Write-Host "Snapshot: $zip"
Write-Host "== Snapshot complete. Client and server keep running. =="
