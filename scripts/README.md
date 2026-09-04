# Test-cycle automation

Two scripts automate the repetitive file-shuffling around each manual test
session. Neither one touches gameplay — starting the server/client, admin
login, and Horde Spawner cleanup remain manual.

## `pretest-setup.ps1`

Run before starting the server and client:

- Mirrors [`Contents/mods/pz-zombie-factions/`](../Contents/mods/pz-zombie-factions/)
  into the local PZ client mods folder (`%USERPROFILE%\Zomboid\mods\pz-zombie-factions`).
- Clears the local client `Logs` folder and `console.txt` so the next run
  starts clean.
- If `scripts/.env.server` exists and is filled in (see below), also mirrors
  the mod to the remote test server and clears its `Logs` folder over SFTP.

## `posttest-cleanup.ps1`

Run after shutting down the server and quitting the client:

- Zips the local client `Logs` folder + `console.txt` into
  `../Logs/client_<timestamp>.zip`.
- If `scripts/.env.server` is filled in, also downloads the remote server's
  `Logs` folder + console log and zips them into `../Logs/server_<timestamp>.zip`.

Both zips land directly in the repo's gitignored [`Logs/`](../Logs/) folder,
matching the existing convention there — no subfolders needed.

## Remote (SFTP) setup

1. Copy `server.env.example` to `.env.server` in this folder and fill in your
   host, port, username, password, and the remote mod/logs paths. This file
   is gitignored and must never be committed or pasted into chat.
2. Run `get-host-fingerprint.ps1 -HostName <host> -Port <port>` and paste the
   reported SHA256 value into `SFTP_HOST_FINGERPRINT_SHA256`. curl refuses to
   connect over SFTP without this. If it prints more than one key type,
   confirm which one curl actually negotiates via a real connection attempt
   (its error reports "Remote ..." with the fingerprint it saw).
3. If you don't know the exact remote paths, list the SFTP root first:
   `curl -sS --user USER:PASS sftp://HOST:PORT/`. One confirmed provider
   layout: `server-data/mods/<modname>`, `server-data/Logs`,
   `server-data/server-console.txt`.
4. Until `.env.server` exists with real (non-placeholder) values, both
   scripts silently skip the remote steps and only do the local half.

**Use Git's curl, not Windows' built-in one.** Both scripts hardcode
`C:\Program Files\Git\mingw64\bin\curl.exe`. Windows' own `System32\curl.exe`
has no SFTP/libssh2 support and fails with `Protocol "sftp" is disabled` —
and on this machine it resolves first on PATH, so a bare `curl.exe` call
picks the wrong one.

The remote download half (`posttest-cleanup.ps1`) has been validated
end-to-end against the real server (listing + downloading real logs
succeeded). The destructive remote steps in `pretest-setup.ps1` — overwriting
the live mod and deleting server logs — have not yet been run for real.
Watch the first live run closely, ideally when no test is in progress on the
server.
