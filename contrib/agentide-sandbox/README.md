# AgentIDE Linux sandbox (`agentide-sandbox`)

Bubblewrap-based privilege crossing for AgentIDE on Linux. The host
user runs payloads as `sandvault-<host>` through a single helper,
matching the shape sandvault provides on macOS without widening the
sudoers surface to a free-form shell.

## Requirements

- Linux with [bubblewrap](https://github.com/containers/bubblewrap)
  (`bwrap` on `$PATH`)
- Root privileges to create the sandbox user and install sudoers
- Optional: `acl` tools (`setfacl`) so both users share
  `/var/lib/agentide/<host>` with default ACLs

## Install

From this directory:

```bash
sudo ./install.sh
```

When not installing through `sudo` (no `SUDO_USER`), pass the GUI
login name:

```bash
sudo ./install.sh alice
```

The installer:

1. Creates `sandvault-<host>` with home `/home/sandvault-<host>`
2. Creates `/var/lib/agentide/<host>` (mode `2770`) and, when
   available, sets default ACLs for both users
3. Installs `enter` to `/usr/libexec/agentide/enter`
4. Installs a sudoers drop-in so the host may run only that helper
   as the sandbox user without a password

## What `enter` does

`enter` parses `--home`, `--shared`, `--workdir`, `--session-id` and
`--session-name`, then `exec`s `bwrap` with:

- `--die-with-parent --new-session`
- `--unshare-pid --unshare-ipc --unshare-uts` (network stays shared)
- Read-only binds of `/usr`, `/lib`, `/lib64`, `/bin`, `/sbin`,
  `/etc/ssl` and `/etc/resolv.conf`
- Read-write binds of the sandbox home and shared workspace
- A `tmpfs` on `/tmp`

It never binds the host user's `HOME`. AgentIDE's
`LinuxSandboxLauncher` builds the argv that reaches this helper.

## Verify

```bash
sudo --login --set-home --user="sandvault-${USER}" \
  /usr/libexec/agentide/enter \
  --home="/home/sandvault-${USER}" \
  --shared="/var/lib/agentide/${USER}" \
  --workdir="/var/lib/agentide/${USER}" \
  --session-id=test --session-name=test \
  -- /bin/bash -lc 'echo ok; pwd; echo "$HOME"'
```

Flatpak packaging is out of scope for this helper.
