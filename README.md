# 🪪 AgentIDE

![The worktree sidebar, an agent's terminal and its review beside it](docs/screenshot.png)

AgentIDE is a native macOS app for running, prompting and reviewing
sandboxed AI coding agents in parallel `git` worktrees, from prompt
to reviewed, merged pull request. Everything a task passes through,
worktree, conversation, review, pull request and CI, is one window in
one app rather than several. Built with SwiftUI on top of
[sandvault](https://github.com/webcoyote/sandvault),
[`herdr`](https://herdr.dev) and the [`gh`](https://cli.github.com) CLI.
This checkout is [petergi/AgentIDE](https://github.com/petergi/AgentIDE),
a fork exploring multi-OS ports (macOS 15+ and experimental Ubuntu),
distinct from the upstream Homebrew cask product.

## 💡 Motivation

My agentic coding setup, described in
[Sandboxes and Worktrees: My secure Agentic AI Setup](https://mikemcquaid.com/sandboxed-agent-worktrees-my-coding-and-ai-setup-in-2026/),
spanned four apps: an agent and worktree manager, a `git` GUI, a code
editor and a terminal. AgentIDE replaces all four with one app designed
around the same workflow. Agents run inside a separate, non-admin
sandvault sandboxed user with no access to sensitive files or
credentials, so they can work unattended without endangering the rest of
the machine, and their sessions live in a `herdr` server owned by the
same sandbox user, so nothing is lost when the app quits, crashes or
updates.

## ✨ Features

- Starts a worktree, a branch and an agent from a prompt, a GitHub issue
  or a pull request, narrating each step until the agent is up.
- Runs Claude Code or Codex CLI as a sandboxed, non-admin user, with
  no permission prompts necessary and no access to your admin user's
  files or credentials.
- Groups worktrees by repository with unread activity, agent state, open
  pull requests, merge conflicts, uncommitted work and drift from what
  was pushed, adopting worktrees made outside the app in the same
  locations.
- Says what a pull request is doing in GitHub's own icons, one glyph per
  fact, watching checks and queued merges until they settle.
- Code reviews uncommitted work, the last commit, unpushed commits, the
  whole branch or any single commit, as a syntax-highlighted diff with
  the pull request's conversations inline under their files.
- Edits uncommitted lines in place in the diff, and files in a built-in
  editor that reads `.editorconfig`, comments with Cmd-/, moves and
  duplicates lines, guides columns 80 and 118 and bars every uncommitted
  line.
- Commits the files you tick rather than the worktree, or adds them to
  the previous commit, with the message drafted by the on-device Apple
  model.
- Pushes, rebases and opens pull requests as drafts or ready for review,
  templates filled in, labels attached, forks used where the repository
  is not yours, pushes following a contributor's fork back to it, and
  branches stacked in one worktree; an open pull request's title and
  body are edited in the same form, to say what was actually pushed.
- Copies unresolved review comments and failing CI logs into a prompt,
  resolves conversations and merges or queues, each with a click.
- Stays quiet while idle, and quieter still on battery, with agent
  and file changes still landing at once.
- Notifies when an agent finishes or needs input, badges the Dock, and
  marks a pane that has held several cores for ten minutes with what is
  running in it.
- Deletes a worktree and its branch once its pull request merges, and
  keeps every conversation browsable and resumable after the worktree is
  gone.
- Starts and steers work from a phone: `agentide new` over SSH, Shortcuts
  and Siri, and `herdr` for the sessions themselves.

## 🚫 Out of Scope

- Windows support.
- Flatpak (and the Mac App Store): neither can honestly `sudo` to another
  uid or create the sandbox user, which is the same reason agents cannot
  run as another user from those sandboxes.
- Running agents without a sandboxed non-admin user.
- Team, multi-user or hosted features: one developer, one machine.
- An agent marketplace or bundled models; bring your own agent CLI.
- A native iOS app: SSH into `herdr` from any iOS client instead.
- An updater of its own; upstream Mac releases upgrade through
  Homebrew's cask, not this fork's builds.
- Linux desktop feature parity with the Mac app: Ubuntu work here is
  scaffolding only.

## 📋 Requirements

### macOS

- macOS Sequoia (15) or later. One binary; Liquid Glass and on-device
  Foundation Models need macOS 26+. If a Sequoia host cannot load the
  Swift 6.4 stdlib, raise the floor to macOS 26 and treat 15 as
  unsupported rather than shipping a broken binary.
- [Homebrew](https://brew.sh), which installs the rest.
- [sandvault](https://github.com/webcoyote/sandvault), which creates the
  sandbox user and the shared workspace.
- [`gh`](https://cli.github.com) authenticated as you; it stays with your
  user and agents never see it.
- [`herdr`](https://herdr.dev) and [`mosh`](https://mosh.org), installed
  by `script/bootstrap`; `mosh` only matters from a phone.
- Xcode 27 or later, only to build from source.

### Ubuntu (parked)

Linux GTK, sandbox `enter` and the inotify stand-in live on
`pause/linux`. This branch does not grow them.

## 📦 Installation

Upstream Mac releases (not this fork) install with:

```bash
brew install --cask agentide
```

The [`agentide` cask](https://github.com/Homebrew/homebrew-cask/blob/main/Casks/a/agentide.rb)
tracks [MikeMcQuaid/AgentIDE](https://github.com/MikeMcQuaid/AgentIDE)
releases, signed with a Developer ID certificate and notarised by Apple.
Without Homebrew, download `AgentIDE-<version>.zip` from that project's
[releases page](https://github.com/MikeMcQuaid/AgentIDE/releases), unzip
it and move `AgentIDE.app` to /Applications.

To run **this** checkout's Mac app from source:

```bash
script/bootstrap
script/build
script/install
```

`script/install` copies the built app into /Applications so the running
copy survives rebuilds. A first launch creates `repositories/` and
`worktrees/` in the shared workspace if they are not there yet. See
[Ports / this fork](#-ports--this-fork) for `agentide-core`; Linux
work is on `pause/linux`.

## 🌐 Ports / this fork

This branch is the Mac app. Linux GTK, `contrib/agentide-sandbox` and
the inotify stand-in are parked on `pause/linux` until the Mac path is
finished. Shared Domain, Data and Runtime stay in this tree; do not
grow the Ubuntu shell here. The Homebrew cask is not built from this
fork.

- **`agentide-core`**: NDJSON stdin/stdout bridge over Domain, Data and
  Runtime. Commands: `ping`, `status`, `roots`, `overview`, `quit`
  (unknown commands reply `{ok:false}` without exiting). Smoke it with
  `script/agentide-core-smoke`, or build and talk to it by hand:

  ```bash
  swift build --product agentide-core
  script/agentide-core-smoke
  ```

- **Parked on `pause/linux`**: `Linux/` (experimental Adwaita shell),
  `contrib/agentide-sandbox` (bubblewrap `enter`), and the Linux file
  watcher. Resume there only after the Mac app is polished.

Mac app from this tree: `script/bootstrap`, then `script/build` or
`script/install` (→ /Applications). Architecture detail is in
[ARCHITECTURE.md](ARCHITECTURE.md).

## ⚙️ Configuration

Settings (Cmd-,) controls:

- **General**: the agent, model and effort new sessions start on, whether
  commits must be signed, and the browser Cmd-click opens.
- **Notifications**: which events notify, badge the Dock and make a
  sound.
- **Editor**: the external editor Cmd-click runs, and the monospace font
  every code surface shares.
- **Advanced**: where repositories and worktrees live, how often the
  system is re-read, idle sleep and the performance log.

A shell pane sets `AGENTIDE=1` and puts the bundled `agentide` command on
`PATH`, so shell files can hand editing back to the app:

```bash
if [ -n "${AGENTIDE}" ]; then
  export EDITOR="$(command -v agentide) --wait"
  export VISUAL="${EDITOR}"
fi
```

`agentide .` from any terminal switches the window to the worktree you
are in.

## 📱 iPhone SSH access

Agents run as the sandbox user, so anything that can SSH to that user
can start and steer them. [Moshi](https://getmoshi.app) is the iOS
client this is currently built around, because it speaks both
[`mosh`](https://mosh.org), so a phone changing network keeps its
session rather than dropping it, and `herdr`, so it attaches to the same
sessions the app does.

1. Put the phone's public key in sandvault's guest template, which is
   what the sandbox home is built from, then rebuild it. A sandvault
   upgrade replaces the template, so keep this in your dotfiles:

   ```bash
   guest_keys="$(brew --prefix sandvault)/libexec/guest/home/.ssh/authorized_keys"
   cat "${HOME}/Downloads/moshi.pub" >>"${guest_keys}"
   sv --rebuild build
   ```

2. Name the shared workspace for logins from outside the sandbox, which
   do not inherit it, in `/etc/ssh/sshd_config.d/000-agentide.conf` with
   your own user name and path in place of `<you>`, then turn on macOS's
   Remote Login for that account:

   ```text
   Match User sandvault-<you>
       SetEnv SHARED_WORKSPACE=/Users/Shared/sv-<you>
   ```

3. In the sandbox user's shell configuration, name the session and give
   the new-session command a short alias:

   ```bash
   export HERDR_SESSION=agentide
   alias ain='/Applications/AgentIDE.app/Contents/Resources/bin/agentide new'
   ```

Connect as `sandvault-<you>` and run `herdr`: one attach presents every
agent's workspace, and `ain` starts a new session, asking for repository,
agent, model, effort and prompt. A session steered from the phone is the
same session the Mac shows.

## 🛠️ Development

- `script/bootstrap`: install `Brewfile` dependencies and generate the
  Xcode project with XcodeGen
- `script/build`: build the app; `AgentIDE.app` in the repository root
  symlinks its output
- `script/version`: print the version and build number git says, which
  scripted and Xcode builds both use
- `script/install`: build, then copy the app to /Applications
- `script/test`: unit, integration and App Intents tests
- `script/style [--fix]`: SwiftLint and SwiftFormat, every rule on
- `script/analyze`: static analysis and dead code
- `script/zip` and `script/package`: zip, sign and notarise a release
- `script/attach`: attach this terminal to the sandboxed `herdr` session
- `script/agentide-core-smoke`: NDJSON dialogue against `agentide-core`

Upstream releases run the **Release** workflow from the Actions tab on
`main` with a bare `MAJOR.MINOR.PATCH` version. Port work on this fork
lives on `cross-platform`; see [Ports / this fork](#-ports--this-fork).

## 🚧 Status

Stable but changing daily on macOS (the product the Mac app still is).
This fork's Ubuntu support is experimental scaffolding
(`agentide-core`, `contrib/agentide-sandbox`, `Linux/`), not a shipping
desktop. Upstream AgentIDE is designed primarily for
[@MikeMcQuaid](https://github.com/MikeMcQuaid)'s personal workflow;
nothing here promises to suit anyone else's, interfaces and behaviour may
break without notice and there is no support.

## 📮 Contact

Upstream: [Mike McQuaid](mailto:mike@mikemcquaid.com).
Port questions for this fork: open an issue on
[petergi/AgentIDE](https://github.com/petergi/AgentIDE).

## 📄 Licence

[AGPL-3.0](LICENSE). If you reuse or adapt the source the AGPL terms
apply, including the network-use clause.

[Octicons](https://github.com/primer/octicons) are vendored in
`App/Assets.xcassets` and licensed under the
[MIT License](https://github.com/primer/octicons/blob/main/LICENSE).
