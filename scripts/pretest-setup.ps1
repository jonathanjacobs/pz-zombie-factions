<#
Pre-test setup for pz-zombie-factions.

Local (always runs):
  - Mirrors Contents/mods/pz-zombie-factions into the local PZ client mods folder.

Remote (only if scripts/.env.server exists and is filled in):
  - Mirrors the same mod folder to the test server over SFTP.

This script deliberately does NOT clear logs on either side any more.

Project Zomboid archives its own logs: at startup it sweeps the previous
session's files out of the Logs folder into a dated logs_<date> subfolder, and
it names each session's files after that session's startup timestamp, so runs
never bleed into each other. Clearing was therefore never needed to keep runs
separate -- and because the archiver skips an empty folder, clearing beforehand
meant no logs_<date> folder was ever created and the test server accumulated no
history at all. Removing the clearing restores the same archive behavior a
normal production server has.

posttest-cleanup.ps1 copies both sides recursively, so those archive folders are
captured too and each zip carries the full history rather than one session. The
zips therefore grow over time; clear repo Logs/ by hand when that becomes
inconvenient.
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModSource = Join-Path $RepoRoot 'Contents\mods\pz-zombie-factions'
$ZomboidDir = Join-Path $env:USERPROFILE 'Zomboid'
$LocalModsDir = Join-Path $ZomboidDir 'mods\pz-zombie-factions'
$EnvFile = Join-Path $PSScriptRoot '.env.server'
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

Write-Host "== Local: deploying mod to $LocalModsDir =="
robocopy $ModSource $LocalModsDir /MIR /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

$config = Import-EnvFile $EnvFile
if (-not $config -or -not $config['SFTP_HOST'] -or $config['SFTP_HOST'] -eq 'your.host.example.com') {
    Write-Host "== Remote: skipped (scripts/.env.server missing or still has placeholder values; see scripts/server.env.example) =="
    Write-Host "== Pre-test setup complete (local only) =="
    exit 0
}

$sftpHost = $config['SFTP_HOST']
$sftpPort = $config['SFTP_PORT']
$sftpUser = $config['SFTP_USER']
$sftpPass = $config['SFTP_PASSWORD']
$hostFingerprint = $config['SFTP_HOST_FINGERPRINT_SHA256']
$remoteModsDir = $config['REMOTE_MODS_DIR'].TrimEnd('/')
$userPass = "${sftpUser}:${sftpPass}"

if (-not (Test-Path $Curl)) { throw "Git's curl.exe (with SFTP support) not found at $Curl" }
if (-not $hostFingerprint) {
    throw "SFTP_HOST_FINGERPRINT_SHA256 is not set in scripts/.env.server. Run scripts/get-host-fingerprint.ps1 -HostName $sftpHost -Port $sftpPort first."
}
$curlArgs = @('--hostpubsha256', $hostFingerprint)

Write-Host "== Remote: uploading mod to sftp://${sftpHost}:${sftpPort}/${remoteModsDir} =="
$files = Get-ChildItem -Path $ModSource -Recurse -File
foreach ($f in $files) {
    $rel = $f.FullName.Substring($ModSource.Length + 1).Replace('\', '/')
    $remotePath = "$remoteModsDir/$rel"
    & $Curl @curlArgs --ftp-create-dirs -sS --user $userPass -T $f.FullName "sftp://${sftpHost}:${sftpPort}/${remotePath}"
    if ($LASTEXITCODE -ne 0) { throw "Upload failed for $rel (curl exit $LASTEXITCODE)" }
}

Write-Host "== Pre-test setup complete (logs left in place for the game to archive) =="
