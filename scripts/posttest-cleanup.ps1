<#
Post-test cleanup for pz-zombie-factions.

Local (always runs):
  - Zips the local client Logs folder + console.txt into repo Logs/client_<stamp>.zip.

Remote (only if scripts/.env.server exists and is filled in):
  - Downloads the remote server Logs folder + console log and zips them into
    repo Logs/server_<stamp>.zip.

Remote steps are unvalidated against a real host as of first authoring --
watch the first real run closely. Repo Logs/ is gitignored; these zips are
never committed.
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ZomboidDir = Join-Path $env:USERPROFILE 'Zomboid'
$LocalLogsDir = Join-Path $ZomboidDir 'Logs'
$LocalConsole = Join-Path $ZomboidDir 'console.txt'
$RepoLogsDir = Join-Path $RepoRoot 'Logs'
$EnvFile = Join-Path $PSScriptRoot '.env.server'
$Stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
# Windows' built-in System32\curl.exe lacks SFTP/libssh2 support; Git's
# bundled curl does not. PATH order on this machine resolves the wrong one.
$Curl = 'C:\Program Files\Git\mingw64\bin\curl.exe'

function Import-EnvFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $config = @{}
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 0) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        $config[$key] = $val
    }
    return $config
}

New-Item -ItemType Directory -Force -Path $RepoLogsDir | Out-Null

Write-Host "== Local: zipping client logs =="
$clientStage = Join-Path $env:TEMP "pzclient_$Stamp"
New-Item -ItemType Directory -Force -Path $clientStage | Out-Null
if (Test-Path $LocalLogsDir) { Copy-Item "$LocalLogsDir\*" $clientStage -Recurse -Force }
if (Test-Path $LocalConsole) { Copy-Item $LocalConsole $clientStage -Force }
$clientZip = Join-Path $RepoLogsDir "client_$Stamp.zip"
Compress-Archive -Path "$clientStage\*" -DestinationPath $clientZip -Force
Remove-Item $clientStage -Recurse -Force
Write-Host "Client zip: $clientZip"

$config = Import-EnvFile $EnvFile
if (-not $config -or -not $config['SFTP_HOST'] -or $config['SFTP_HOST'] -eq 'your.host.example.com') {
    Write-Host "== Remote: skipped (scripts/.env.server missing or still has placeholder values; see scripts/server.env.example) =="
    Write-Host "== Post-test cleanup complete (local only) =="
    exit 0
}

$sftpHost = $config['SFTP_HOST']
$sftpPort = $config['SFTP_PORT']
$sftpUser = $config['SFTP_USER']
$sftpPass = $config['SFTP_PASSWORD']
$hostFingerprint = $config['SFTP_HOST_FINGERPRINT_SHA256']
$remoteLogsDir = $config['REMOTE_LOGS_DIR'].TrimEnd('/')
$remoteConsole = $config['REMOTE_CONSOLE_LOG']
$userPass = "${sftpUser}:${sftpPass}"

if (-not (Test-Path $Curl)) { throw "Git's curl.exe (with SFTP support) not found at $Curl" }
if (-not $hostFingerprint) {
    throw "SFTP_HOST_FINGERPRINT_SHA256 is not set in scripts/.env.server. Run scripts/get-host-fingerprint.ps1 -HostName $sftpHost -Port $sftpPort first."
}
$curlArgs = @('--hostpubsha256', $hostFingerprint)

Write-Host "== Remote: downloading server logs from $remoteLogsDir =="
$serverStage = Join-Path $env:TEMP "pzserver_$Stamp"
New-Item -ItemType Directory -Force -Path $serverStage | Out-Null

$listing = & $Curl @curlArgs -sS --user $userPass "sftp://${sftpHost}:${sftpPort}/${remoteLogsDir}/"
foreach ($line in ($listing -split "`n")) {
    $parts = $line.Trim() -split '\s+'
    $name = $parts[-1]
    if ($name -and $name -ne '.' -and $name -ne '..') {
        & $Curl @curlArgs -sS --user $userPass -o (Join-Path $serverStage $name) "sftp://${sftpHost}:${sftpPort}/${remoteLogsDir}/${name}"
    }
}
if ($remoteConsole) {
    & $Curl @curlArgs -sS --user $userPass -o (Join-Path $serverStage 'server-console.txt') "sftp://${sftpHost}:${sftpPort}/${remoteConsole}"
}

$serverZip = Join-Path $RepoLogsDir "server_$Stamp.zip"
Compress-Archive -Path "$serverStage\*" -DestinationPath $serverZip -Force
Remove-Item $serverStage -Recurse -Force
Write-Host "Server zip: $serverZip"

Write-Host "== Post-test cleanup complete. Zips are in $RepoLogsDir (gitignored, never committed) =="
