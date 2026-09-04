<#
Pre-test setup for pz-zombie-factions.

Local (always runs):
  - Mirrors Contents/mods/pz-zombie-factions into the local PZ client mods folder.
  - Clears the local client Logs folder and console.txt.

Remote (only if scripts/.env.server exists and is filled in):
  - Mirrors the same mod folder to the test server over SFTP.
  - Clears the remote server Logs folder.

Remote steps are unvalidated against a real host as of first authoring --
watch the first real run closely.
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModSource = Join-Path $RepoRoot 'Contents\mods\pz-zombie-factions'
$ZomboidDir = Join-Path $env:USERPROFILE 'Zomboid'
$LocalModsDir = Join-Path $ZomboidDir 'mods\pz-zombie-factions'
$LocalLogsDir = Join-Path $ZomboidDir 'Logs'
$LocalConsole = Join-Path $ZomboidDir 'console.txt'
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

Write-Host "== Local: clearing client logs =="
if (Test-Path $LocalLogsDir) {
    Get-ChildItem $LocalLogsDir -File -Recurse | Remove-Item -Force
}
if (Test-Path $LocalConsole) {
    Remove-Item $LocalConsole -Force
}

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
$remoteLogsDir = $config['REMOTE_LOGS_DIR'].TrimEnd('/')
$remoteConsole = $config['REMOTE_CONSOLE_LOG']
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

Write-Host "== Remote: clearing server logs in $remoteLogsDir =="
$listing = & $Curl @curlArgs -sS --user $userPass "sftp://${sftpHost}:${sftpPort}/${remoteLogsDir}/"
foreach ($line in ($listing -split "`n")) {
    $parts = $line.Trim() -split '\s+'
    $name = $parts[-1]
    if ($name -and $name -ne '.' -and $name -ne '..') {
        Write-Host "  removing $name"
        & $Curl @curlArgs -sS --user $userPass -Q "rm ${remoteLogsDir}/${name}" -o NUL "sftp://${sftpHost}:${sftpPort}/"
    }
}

if ($remoteConsole) {
    Write-Host "== Remote: clearing $remoteConsole =="
    & $Curl @curlArgs -sS --user $userPass -Q "rm ${remoteConsole}" -o NUL "sftp://${sftpHost}:${sftpPort}/"
}

Write-Host "== Pre-test setup complete =="
