# Test-cycle automation

Three scripts automate the repetitive file-shuffling around each manual test
session. None of them touch gameplay — starting the server/client, admin
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
  `Logs` folder (recursively — any subfolder found under it is walked and
  reproduced locally, not just its top level) plus the console log, and zips
  them into `../Logs/server_<timestamp>.zip`.

Both zips land directly in the repo's gitignored [`Logs/`](../Logs/) folder,
matching the existing convention there — no subfolders needed. As of this
writing neither side has ever actually created a subfolder under its Logs
directory (both are flat, one file per category); the recursive walk is
defensive, in case a future PZ version or server config changes that.

## `snapshot-client-log.ps1`

Run mid-session, between distinct sub-tests, without stopping the client or
server:

- Copies (does not clear) the current local client `Logs` folder +
  `console.txt` into `../Logs/client-snapshot_<timestamp>.zip`.

The client's `DebugLog.txt` is a single file that PZ caps in place at
roughly 4.3MB observed on this machine: once a session's log volume crosses
that line, the file silently drops its own *oldest* lines to make room for
new ones, with no rotated backup left to recover them from afterward. The
server-side log has no equivalent cap (a 7.25MB same-session server log
showed no truncation), so this is a client-only concern.

Practically: in one long session mixing a small-scale test with a
mass-combat stress test, the mass-combat volume alone is enough to push the
small-scale phase's detail out of the live file before the session ends —
`posttest-cleanup.ps1` then only recovers whatever's left in the tail. Run
`snapshot-client-log.ps1` right after each phase you want preserved, before
starting the next one, and check the resulting zip alongside the final
post-test zips.

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

Both scripts' remote steps have now been validated end-to-end against the
real server: `pretest-setup.ps1`'s destructive path (overwriting the live
mod, deleting server logs) and `posttest-cleanup.ps1`'s download path
(listing + downloading real logs, now recursively) have each completed a
real run without incident.

One quirk observed in that run: `pretest-setup.ps1`'s final `rm` on the
remote console log exits nonzero (curl exit 21) whenever that file doesn't
already exist — which is normal, since the server recreates it fresh on
startup. Read that exit code as "already absent," not as a failure; the
script doesn't check `$LASTEXITCODE` after that call, so it still completes
the rest of its work either way.
