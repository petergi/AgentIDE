# macOS 15 Backport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One AgentIDE binary that runs on macOS 27, 26 and 15, built by Xcode 27 or Xcode 26, with Liquid Glass and on-device drafting where the OS has them and honest fallbacks where it does not.

**Architecture:** Lower the deployment floor to 15.0 and gate the four places the code reaches past it: the FoundationModels call (one `#available`), the Liquid Glass button styles (one wrapper in TerminalUI), the drop handler's overload choice (return the Bool), and one Swift 6.3 name-lookup difference (a rename). Everything else already compiles and its tests already pass at the lower floor; the rest of the work is CI, documentation and a manual QA matrix on real machines.

**Tech Stack:** Swift 6.2 tools version, SwiftPM, XcodeGen (`project.yml`), Swift Testing, GitHub Actions (`xcode-27` and `macos-15` runners), `otool`.

**Spec:** `docs/superpowers/specs/2026-09-06-multi-platform-design.md` (WP-A in §9; the evidence is §2.1 and the review's `01-compile-tests.md` and `backport-ui-audit.md`).

## Global Constraints

- Deployment floor `15.0` in both `Package.swift` (`platforms`) and `project.yml` (`deploymentTarget.macOS`, `MACOSX_DEPLOYMENT_TARGET` on both targets); never one without the other.
- `swift-tools-version: 6.2` stays; the code must compile with Swift 6.3 (Xcode 26) and Swift 6.4 (Xcode 27).
- No `#available` at call sites when a wrapper can hold it: exactly one availability check for the glass styles and one for FoundationModels.
- UK English in docs, comments and UI strings; commit messages sentence-case imperative with no conventional-commit prefix.
- Before each commit: `script/style --fix`, then `script/test` and `script/analyze` when Swift changed (the sandbox cannot run the analyser's passes; say so if you are in it). README and ARCHITECTURE change in the same commit as the behaviour they describe.
- The working tree may already contain some of these changes (an uncommitted scaffold). A task marked *verify* checks the tree and commits what is there; a task marked *apply* writes the change. Never redo what the tree already has.

---

### Task 1: Platform floors (verify)

**Files:**
- Modify: `Package.swift:12` (`platforms`)
- Modify: `project.yml` (`options.deploymentTarget.macOS`, `MACOSX_DEPLOYMENT_TARGET` under `AgentIDEApp` and `AgentIDEIntentTests`)

**Interfaces:**
- Consumes: nothing.
- Produces: the floor every later task's `#available` checks are measured against.

- [ ] **Step 1: Check what the tree says**

Run: `grep -n 'macOS(' Package.swift; grep -nE 'macOS: "|MACOSX_DEPLOYMENT_TARGET' project.yml`
Expected: `platforms: [.macOS("15.0")]` and three `15.0` values. If any still reads `27.0`, change it to `15.0`.

- [ ] **Step 2: Prove the manifest resolves**

Run: `swift package dump-package | python3 -c 'import json,sys; print(json.load(sys.stdin)["platforms"])'`
Expected: `[{'platformName': 'macos', 'version': '15.0', ...}]`

- [ ] **Step 3: Commit**

```bash
git add Package.swift project.yml
git commit -m "Lower the deployment target to macOS 15"
```

### Task 2: Gate the on-device model (verify, then add the test)

**Files:**
- Modify: `Sources/AgentIDEData/FoundationModelClient.swift` (`respond(instructions:to:)`)
- Test: `Tests/AgentIDEDataTests/FoundationModelClientTests.swift`

**Interfaces:**
- Consumes: `SystemLanguageModel`, `LanguageModelSession` (macOS 26+).
- Produces: `FoundationModelClient.respond(instructions:to:) async -> String?` answering nil below macOS 26; every caller already handles nil.

- [ ] **Step 1: Check the gate is present**

Run: `grep -n '#available(macOS 26' Sources/AgentIDEData/FoundationModelClient.swift`
Expected: one hit inside `respond`. If absent, replace the body's first lines with:

```swift
guard isEnabled else {
    return nil
}

if #available(macOS 26.0, *) {
    guard SystemLanguageModel.default.isAvailable else {
        return nil
    }

    let session = LanguageModelSession(instructions: instructions)
    return try? await session.respond(to: input).content
}
return nil
```

- [ ] **Step 2: Write the test**

Append to `FoundationModelClientTests.swift`:

```swift
@Test
func `answers nil where the framework is unavailable`() async {
    if #available(macOS 26.0, *) {
        // The framework exists here; availability is a runtime fact
        // on 26 and this test asserts only the older path.
        return
    }
    let client = FoundationModelClient()
    #expect(await client.respond(instructions: "Say hi", to: "hi") == nil)
}
```

- [ ] **Step 3: Run the suite**

Run: `swift test --filter FoundationModelClientTests`
Expected: PASS (on a macOS 26 or 27 host the new test returns early and passes; on 15 it exercises the gate).

- [ ] **Step 4: Commit**

```bash
git add Sources/AgentIDEData/FoundationModelClient.swift Tests/AgentIDEDataTests/FoundationModelClientTests.swift
git commit -m "Gate the on-device model behind macOS 26"
```

### Task 3: Compile under Swift 6.3 (verify)

**Files:**
- Modify: `Sources/AgentIDEData/PullRequestStore.swift:239-248` (`queuedNumbers`)

**Interfaces:**
- Consumes: `due(_:interval:floor:)` on the store.
- Produces: no change in behaviour; the local is named `duePaths`.

- [ ] **Step 1: Check the rename**

Run: `grep -n 'let due = \|duePaths' Sources/AgentIDEData/PullRequestStore.swift`
Expected: `duePaths` at the filter, the `contains`, the `isEmpty` and the `queuedNumbers(repositoryPaths:)` call; no `let due =`. If the old form remains, rename the local to `duePaths` and call the method as `self.due(...)`.

- [ ] **Step 2: Prove Xcode 26 builds the target**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --target AgentIDEData` (on a machine whose Xcode is 26.x)
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/AgentIDEData/PullRequestStore.swift
git commit -m "Name the due repositories so Swift 6.3 resolves the call"
```

### Task 4: One wrapper for Liquid Glass (verify, then sweep)

**Files:**
- Modify: `Sources/TerminalUI/GlassStyle.swift` (the wrapper; present in the tree)
- Modify: the eleven call sites in `Sources/TerminalUI/BusyButton.swift`, `Sources/TerminalUI/RefreshButton.swift`, `Sources/PRFeature/PullRequestRowView.swift`, `Sources/PRFeature/PullRequestFooterView+Editing.swift`, `Sources/PRFeature/PullRequestCreateForm.swift`, `Sources/ReviewFeature/FileEditorView.swift`, `App/RootView+Panes.swift`, `App/RootView+SessionTabs.swift`

**Interfaces:**
- Consumes: `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` (macOS 26+), `.bordered`, `.borderedProminent`.
- Produces: the two wrapper modifiers `GlassStyle.swift` declares (read their names from the file; the scaffold names them `agentGlassButtonStyle()` and `agentGlassProminentButtonStyle()`).

- [ ] **Step 1: Find any raw site left**

Run: `grep -rnE '\.buttonStyle\(\.glass(Prominent)?\)' Sources App | grep -v GlassStyle.swift`
Expected: no output. Each hit is replaced with the matching wrapper modifier.

- [ ] **Step 2: Build the UI targets at the floor**

Run: `swift build --target AgentIDEAppSources`
Expected: `Build complete!` with no "only available in macOS 26.0" error.

- [ ] **Step 3: Commit**

```bash
git add Sources/TerminalUI/GlassStyle.swift Sources App
git commit -m "Choose glass or bordered buttons by the running macOS"
```

### Task 5: The drop handler's overload (apply)

**Files:**
- Modify: `App/RootView+Panes.swift:53-60`

**Interfaces:**
- Consumes: `dropFiles(_:into:) -> Bool` in `App/RootView+SessionTabs.swift:196`.
- Produces: a drop handler resolving to `dropDestination(for:action:isTargeted:)` (macOS 13+) rather than the macOS 26 `dropDestination(for:isEnabled:action:)`.

- [ ] **Step 1: Rewrite the comment and the closure**

Replace lines 53–60 with:

```swift
                // Dropped files stage into the shared workspace (the
                // sandbox cannot read host paths) and their staged
                // paths type into the agent. The closure returns the
                // staging's verdict: a Void closure would pick the
                // macOS 26 drop-session overload and break the floor.
                .dropDestination(for: URL.self) { urls, _ in
                    dropFiles(urls, into: session.name)
                }
```

- [ ] **Step 2: Build at the floor**

Run: `swift build --target AgentIDEAppSources`
Expected: `Build complete!`; before the change the same command fails with `'dropDestination(for:isEnabled:action:)' is only available in macOS 26.0 or newer`.

- [ ] **Step 3: Commit**

```bash
git add App/RootView+Panes.swift
git commit -m "Answer the drop with its verdict so the macOS 13 overload is chosen"
```

### Task 6: Guard before reading the private WebKit key (apply)

**Files:**
- Modify: `Sources/SessionFeature/BrowserPanes.swift:71-72`

**Interfaces:**
- Consumes: `WKWebView` KVC key `_webProcessIdentifier`.
- Produces: `processIdentifier(of:)` (or whatever the surrounding function is named) returning nil, never throwing, on a WebKit without the key.

- [ ] **Step 1: Reorder**

Make the `responds(to:)` check the first statement and the `value(forKey:)` read conditional on it:

```swift
guard webView.responds(to: NSSelectorFromString("_webProcessIdentifier")),
      let number = webView.value(forKey: "_webProcessIdentifier") as? NSNumber
else {
    return nil
}
return number.int32Value
```

(Adapt the surrounding names to the file; the order is the change.)

- [ ] **Step 2: Build and run the SessionFeature suite**

Run: `swift build --target SessionFeature && swift test --filter SessionFeatureTests`
Expected: `Build complete!`; tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/SessionFeature/BrowserPanes.swift
git commit -m "Check the web view answers the private key before reading it"
```

### Task 7: Compare the quarantine test's paths through one normaliser (apply)

**Files:**
- Modify: `Tests/AgentIDEDataTests/QuarantineTests.swift:28-29`

**Interfaces:**
- Consumes: `Quarantine.clear(for:binaryDirectories:) -> [String]`, `TestSupport.canonical(_:)`.
- Produces: a test that passes under any scratch root, including `/var/folders` and a checkout path over 68 characters.

- [ ] **Step 1: Run the test from a deep scratch root to see it fail**

Run: `mkdir -p /private/tmp/agentide-deep/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa && cp -R . /private/tmp/agentide-deep/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/src && (cd /private/tmp/agentide-deep/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/src && swift test --filter QuarantineTests)`
Expected: FAIL with `Expectation failed: (cleared → ["/private/var/folders/…"]) == (… → ["/var/folders/…"])` (TestSupport falls back to the temporary directory when the checkout path is long).

- [ ] **Step 2: Normalise both sides**

Replace lines 28–29 with:

```swift
        let expected = ["codex", "codex-helper"].map { cask + "/" + $0 }
        #expect(cleared.map(TestSupport.canonical) == expected.map(TestSupport.canonical))
```

- [ ] **Step 3: Run it in both roots**

Run: `swift test --filter QuarantineTests` here and in the deep copy from step 1
Expected: PASS in both. Remove the deep copy afterwards: `rm -rf /private/tmp/agentide-deep`.

- [ ] **Step 4: Commit**

```bash
git add Tests/AgentIDEDataTests/QuarantineTests.swift
git commit -m "Compare the quarantine test's paths through one normaliser"
```

### Task 8: CI proves the floor on both toolchain generations (apply)

**Files:**
- Modify: `.github/workflows/tests.yml` (the `build-macos15` job the tree already has, plus a new `macos-15` job)

**Interfaces:**
- Consumes: the `xcode-27` runner label, the GitHub-hosted `macos-15` image (macOS 15.7, Xcode 26.x installed beside 16.4).
- Produces: two required checks, `build-macos15` and `test-macos15`.

- [ ] **Step 1: Make `build-macos15` build everything**

Replace the three `--target` invocations in the job's "Compile for macOS 15 deployment" step with:

```yaml
      - name: Build every target and the tests at the floor
        run: |
          swift build --disable-sandbox --jobs 6
          swift build --disable-sandbox --jobs 6 --build-tests
```

(The manifest's `platforms` already sets the floor; a `-target` flag is not needed and would fight the manifest.)

- [ ] **Step 2: Add the Xcode 26 job**

Append to `jobs:`:

```yaml
  test-macos15:
    runs-on: macos-15
    timeout-minutes: 30
    steps:
      - name: Set up Git repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Select the newest Xcode 26
        run: |
          xcode="$(ls -d /Applications/Xcode_26*.app | sort -V | tail -1)"
          sudo xcode-select -s "${xcode}/Contents/Developer"
          xcodebuild -version

      - name: Build at the floor with Swift 6.3
        run: swift build --jobs 3

      - name: Run the suites that need neither herdr nor a bundle
        run: |
          swift test --jobs 3 --filter 'AgentIDEDomainTests|DashboardFeatureTests|PRFeatureTests|ReviewFeatureTests|SessionFeatureTests|TerminalUITests'
          swift test --jobs 3 --filter AgentIDEDataTests --skip Integration --skip Herdr
```

What this job cannot run, and why: the herdr-backed integration suites (no herdr on the image), the App Intents bundle (needs `xcodebuild` with a signing team) and the app bundle itself (XcodeGen and the `xcode-27` SDK build it in `tests`).

- [ ] **Step 3: Lint the workflow**

Run: `script/style`
Expected: `actionlint` and `zizmor` pass; the only `uses:` entries are `actions/*` (the style gate refuses any other action).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/tests.yml
git commit -m "Prove the macOS 15 floor on Xcode 26 and Xcode 27 in CI"
```

### Task 9: Documentation names the floor (apply)

**Files:**
- Modify: `README.md` ("Requirements": "macOS Golden Gate (27) or later" → "macOS Sequoia (15) or later; Liquid Glass and on-device drafting need macOS 26 or later"; remove any sentence suggesting a Sequoia host might not load the Swift stdlib, since Swift is ABI-stable)
- Modify: `ARCHITECTURE.md` ("Overview": "macOS 27 or later" → "macOS 15 or later")
- Modify: `AGENTS.md` (anywhere it names 27 as the floor rather than as the beta the platform notes were found on)

**Interfaces:**
- Consumes: nothing.
- Produces: docs that describe the behaviour after Tasks 1–8.

- [ ] **Step 1: Find every floor statement**

Run: `grep -nE '27\)? or later|macOS 27' README.md ARCHITECTURE.md AGENTS.md`
Expected: the "Requirements" line, the "Overview" line and the platform-notes heading; only the first two change.

- [ ] **Step 2: Edit and check wrapping**

Edit the two lines; run `script/style` (it fails on any AGENTS.md line over 72 columns).
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add README.md ARCHITECTURE.md AGENTS.md
git commit -m "Say macOS 15 is the floor and what needs 26"
```

### Task 10: Confirm the weak link reaches the app binary (apply)

**Files:**
- Modify (only if the check fails): `project.yml` (`OTHER_LDFLAGS` on `AgentIDEApp`)

**Interfaces:**
- Consumes: the built app from `script/build`.
- Produces: an app that loads on macOS 15 without FoundationModels present.

- [ ] **Step 1: Build and inspect**

Run: `script/build && otool -l .DerivedData/Build/Products/Debug/AgentIDE.app/Contents/MacOS/AgentIDE | grep -B2 -A3 FoundationModels`
Expected: the framework appears under `LC_LOAD_WEAK_DYLIB`. If it appears under `LC_LOAD_DYLIB`, the Data target's linker flag did not propagate.

- [ ] **Step 2: Only if it did not propagate, add the flag to the app target**

In `project.yml` under `AgentIDEApp.settings.base`:

```yaml
        OTHER_LDFLAGS: "$(inherited) -weak_framework FoundationModels"
```

Re-run step 1. Expected: `LC_LOAD_WEAK_DYLIB`.

- [ ] **Step 3: Commit (only if `project.yml` changed)**

```bash
git add project.yml
git commit -m "Weak-link FoundationModels from the app as well as the package"
```

### Task 11: Manual QA on real machines (apply)

**Files:**
- Create: `docs/superpowers/plans/2026-09-06-macos-15-backport-qa.md` (the ticked checklist and the machine each row ran on)

**Interfaces:**
- Consumes: a build from Task 10 installed with `script/install` on macOS 15, 26 and 27 machines or virtual machines, each with sandvault and herdr installed.
- Produces: a signed-off checklist; any failure becomes a new task before the pull request opens.

- [ ] **Step 1: Install on each machine**

Run: `script/install` on each. On macOS 15 `brew install herdr` compiles from source (no Sequoia bottle) or use herdr's own installer; record which.

- [ ] **Step 2: Tick the matrix on each OS**

```markdown
| Check | 15 | 26 | 27 |
|---|---|---|---|
| App launches; About shows the version | | | |
| Window comes back at its saved size, on its saved display, fullscreen if it was | | | |
| Buttons: glass on 26/27, bordered on 15; primary action still reads as primary | | | |
| Editor and diff hunks lay out without overlap; heights match text (TextKit 1 path) | | | |
| Toolbar keeps its trailing group; nothing reflows to the leading edge | | | |
| Start a session; launch narration; agent pane paints; paste wraps in bracketed-paste markers | | | |
| Notifications, sound and Dock badge fire for a finished agent | | | |
| Commit message Draft: works on 26/27; on 15 the field is left alone and Messages says the model is unavailable | | | |
| Shortcuts: "What needs me in AgentIDE" resolves on 15 (App Intents without AppIntentsTesting) | | | |
| `agentide --wait` from a shell pane opens the editor and returns the exit status | | | |
| sandvault and herdr install and the first `sudo` launch succeeds | | | |
```

- [ ] **Step 3: Commit the ticked file**

```bash
git add docs/superpowers/plans/2026-09-06-macos-15-backport-qa.md
git commit -m "Record the macOS 15, 26 and 27 QA pass"
```

### Task 12: Gates and the pull request

**Files:** none new.

- [ ] **Step 1: Style, tests, analysis**

Run: `script/style --fix && script/test && script/analyze`
Expected: all pass on the host (in the sandbox `script/analyze` stops after compiling and says so; run it on the host before opening the pull request).

- [ ] **Step 2: Open the pull request with both refs named**

```bash
git push --set-upstream origin macos-15-floor
gh pr create --head macos-15-floor --base main --title "Support macOS 15, 26 and 27" --body-file docs/superpowers/plans/2026-09-06-macos-15-backport-qa.md
```

## Self-review

- Spec coverage: §2.1 of the design lists the floor, the gate, the rename, the wrapper and the drop handler (Tasks 1–5); `backport-ui-audit.md` adds the BrowserPanes order (Task 6) and the `otool` check (Task 10); `01-compile-tests.md` adds the QuarantineTests fix (Task 7); CI, docs and QA are Tasks 8, 9 and 11; AGENTS.md's gates are Task 12.
- Placeholders: none; every code step carries the code, every check the command and its expected output.
- Names: `duePaths` (Task 3), the wrapper modifiers as `GlassStyle.swift` declares them (Task 4), `dropFiles(_:into:) -> Bool` (Task 5), `TestSupport.canonical` (Task 7), the job names `build-macos15` and `test-macos15` (Task 8) are used consistently.
