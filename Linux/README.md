# AgentIDE on Linux (GTK scaffolding)

Experimental Adwaita shell that drives the shared `agentide-core`
NDJSON process. The sidebar lists `overview` worktrees; the content
pane is a VTE placeholder when `vte-2.91-gtk4` is present. Session
attach is not wired. Flatpak packaging is out of scope.

## Dependencies

- [Meson](https://mesonbuild.com) ≥ 1.0
- `valac` (Vala compiler)
- `libadwaita-1` development files (≥ 1.4)
- A built `agentide-core` on `$PATH` (from this repository's Swift
  package: `swift build --product agentide-core`)

On Debian/Ubuntu:

```bash
sudo apt install meson valac libadwaita-1-dev libjson-glib-dev \
  libvte-2.91-gtk4-dev
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

The window titles itself AgentIDE, asks `agentide-core` for
`overview`, lists those worktrees in the sidebar, and shows a VTE
(or StatusPage) placeholder in the content pane.

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
