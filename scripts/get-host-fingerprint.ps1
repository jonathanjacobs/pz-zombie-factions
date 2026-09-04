<#
Prints SHA256 fingerprints for a host's SSH host keys, for pasting into
SFTP_HOST_FINGERPRINT_SHA256 in scripts/.env.server.

curl/libssh2 doesn't always negotiate the same key type ssh-keyscan lists
first (this host uses RSA, not the more common ed25519), so this prints all
of them, labeled -- pick whichever one a real curl connection attempt reports
as "Remote ..." in its mismatch error, or just try the first one.

Usage: pwsh scripts/get-host-fingerprint.ps1 -HostName 1.2.3.4 -Port 22
#>

param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [int]$Port = 22
)

$ErrorActionPreference = 'Stop'
$tmp = Join-Path $env:TEMP "hostkeys_$([guid]::NewGuid()).txt"

& ssh-keyscan.exe -p $Port -t rsa,ecdsa,ed25519 $HostName 2>$null > $tmp

Get-Content $tmp | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
    $line = $_
    $keyType = ($line -split '\s+')[1]
    $single = Join-Path $env:TEMP "onekey_$([guid]::NewGuid()).txt"
    Set-Content -Path $single -Value $line
    $fp = & ssh-keygen.exe -lf $single -E sha256
    Write-Host "$keyType : $fp"
    Remove-Item $single -Force
}

Remove-Item $tmp -Force
Write-Host ""
Write-Host "Paste the SHA256:... value (without the 'SHA256:' prefix) for the key curl actually uses into SFTP_HOST_FINGERPRINT_SHA256."
