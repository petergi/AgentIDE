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
spawns `agentide-core` with a `ping` command. A successful reply
updates the content label to `agentide-core: pong`.

## Sandbox

Install the Linux sandbox helpers from
[`contrib/agentide-sandbox`](../contrib/agentide-sandbox/README.md)
before expecting host-to-sandbox launches to work.
