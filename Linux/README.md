# AgentIDE on Linux (GTK scaffolding)

Experimental Adwaita shell that drives the shared `agentide-core`
NDJSON process. This is scaffolding only: no session UI, no VTE
terminal pane yet, and Flatpak packaging is out of scope.

## Dependencies

- [Meson](https://mesonbuild.com) ≥ 1.0
- `valac` (Vala compiler)
- `libadwaita-1` development files (≥ 1.4)
- A built `agentide-core` on `$PATH` (from this repository's Swift
  package: `swift build --product agentide-core`)

Optional later: `vte-2.91` for a terminal pane.

On Debian/Ubuntu:

```bash
sudo apt install meson valac libadwaita-1-dev
```

## Build

```bash
cd Linux
meson setup build
meson compile -C build
```

Run (with `agentide-core` on `$PATH`):

```bash
export PATH="$(pwd)/../.build/debug:${PATH}"
./build/agentide
```

The window titles itself AgentIDE, shows a sidebar placeholder, and
spawns `agentide-core` with a `status` command. A successful reply
updates the content label with the platform and version.

Smoke the NDJSON bridge without GTK:

```bash
script/agentide-core-smoke
```

## agentide-core commands

One JSON object per stdin line; one reply object per stdout line.

| cmd | reply |
| --- | --- |
| `ping` | `{ok, pong}` |
| `status` | `{ok, platform, version, sandboxed}` |
| `roots` | `{ok, hostUser, sharedWorkspace, sandboxHome, metadataFile, sharedTemporaryDirectory}` |
| `overview` | `{ok, worktrees:[{repositoryName, worktreePath, branch, sessionName?, agentActivity?}]}` |
| `quit` | `{ok}` |

Unknown commands and invalid JSON answer `{ok:false, error:"…"}`
without exiting.

## Sandbox

Install the Linux sandbox helpers from
[`contrib/agentide-sandbox`](../contrib/agentide-sandbox/README.md)
before expecting host-to-sandbox launches to work.
