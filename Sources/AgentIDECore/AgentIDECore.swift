import AgentIDEData
import AgentIDEDomain
import AgentIDERuntime
import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

// MARK: - AgentIDECore

/// Headless NDJSON bridge the Linux GTK UI (and tests) speak to.
/// Commands arrive one JSON object per line on stdin; replies are
/// one JSON object per line on stdout.
@main
@MainActor
enum AgentIDECore {
    // MARK: Internal

    static func main() async {
        // Keep Runtime in the executable graph for the GTK poll loop.
        _ = AgentIDERuntime()

        let roots = PlatformRoots.detect()
        PerformanceLog.sharedTemporaryDirectory = roots.sharedTemporaryDirectory
        let service = makeSessionService()

        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                continue
            }

            do {
                let command = try Self.decode(trimmed)
                switch command.cmd {
                case "ping":
                    try Self.emit(PingReply(ok: true, pong: true))

                case "roots":
                    let detected = PlatformRoots.detect()
                    try Self.emit(
                        RootsReply(
                            ok: true,
                            hostUser: detected.hostUser,
                            sharedWorkspace: detected.sharedWorkspace,
                            sandboxHome: detected.sandboxHome,
                            metadataFile: detected.metadataFile,
                            sharedTemporaryDirectory: detected.sharedTemporaryDirectory,
                        ),
                    )

                case "status":
                    try Self.emit(
                        StatusReply(
                            ok: true,
                            platform: Self.platformName,
                            version: Self.coreVersion(),
                            sandboxed: WorkspacePaths.isInsideSandbox,
                        ),
                    )

                case "overview":
                    let overview = await service.overview()
                    let worktrees = overview.groups.flatMap { group in
                        group.items.map { item in
                            OverviewWorktree(
                                repositoryName: item.worktree.repositoryName,
                                worktreePath: item.worktree.path,
                                branch: item.worktree.branch,
                                sessionName: item.session?.name,
                                agentActivity: item.session?.activity.map(Self.activityName),
                            )
                        }
                    }
                    try Self.emit(OverviewReply(ok: true, worktrees: worktrees))

                case "quit":
                    try Self.emit(OkReply(ok: true))
                    return

                default:
                    try Self.emit(ErrorReply(ok: false, error: "unknown cmd: \(command.cmd)"))
                }
            } catch {
                try? Self.emit(ErrorReply(ok: false, error: Self.errorMessage(for: error)))
            }
        }
    }

    // MARK: Private

    private struct Command: Decodable {
        let cmd: String
    }

    private struct PingReply: Encodable {
        let ok: Bool
        let pong: Bool
    }

    private struct OkReply: Encodable {
        let ok: Bool
    }

    private struct ErrorReply: Encodable {
        let ok: Bool
        let error: String
    }

    private struct RootsReply: Encodable {
        let ok: Bool
        let hostUser: String
        let sharedWorkspace: String
        let sandboxHome: String
        let metadataFile: String
        let sharedTemporaryDirectory: String
    }

    private struct StatusReply: Encodable {
        let ok: Bool
        let platform: String
        let version: String
        let sandboxed: Bool
    }

    /// One dashboard row: stable field names for the GTK shell.
    private struct OverviewWorktree: Encodable {
        let repositoryName: String
        let worktreePath: String
        let branch: String
        let sessionName: String?
        let agentActivity: String?
    }

    private struct OverviewReply: Encodable {
        let ok: Bool
        let worktrees: [OverviewWorktree]
    }

    private enum CoreError: Error, LocalizedError {
        case invalidUTF8

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .invalidUTF8:
                "invalid UTF-8"
            }
        }
    }

    private static var platformName: String {
        #if os(macOS)
            "macOS"
        #elseif os(Linux)
            "linux"
        #else
            "unknown"
        #endif
    }

    /// Composes SessionService the way the Mac app does, with the
    /// platform's sandbox launcher and no on-device summariser.
    private static func makeSessionService() -> SessionService {
        let paths = WorkspacePaths.current()
        let runner = FoundationProcessRunner()
        let gitClient = GitClient(runner: runner)
        let githubClient = GitHubClient(runner: runner)
        let metadataStore = MetadataStore(file: paths.metadataFile)
        let launcher = makeLauncher(hostUser: paths.hostUser)
        let herdr = HerdrClient(
            runner: runner,
            launcher: launcher,
            isInsideSandbox: WorkspacePaths.isInsideSandbox,
        )
        return SessionService(
            paths: paths,
            git: gitClient,
            herdr: herdr,
            github: githubClient,
            transcripts: TranscriptReader(),
            spool: EventSpool(directory: paths.eventsDirectory),
            store: metadataStore,
            runners: [ClaudeCodeRunner(), CodexRunner()],
            launcher: launcher,
            summariser: NullSummariser(),
        )
    }

    private static func makeLauncher(hostUser: String) -> any SandboxLaunching {
        #if os(macOS)
            SandvaultLauncher(hostUser: hostUser)
        #elseif os(Linux)
            LinuxSandboxLauncher(hostUser: hostUser)
        #else
            fatalError("agentide-core only supports macOS and Linux")
        #endif
    }

    /// Prefer `AGENTIDE_VERSION`, then `git describe`, then a
    /// development placeholder so status always names something.
    private static func coreVersion() -> String {
        if let env = ProcessInfo.processInfo.environment["AGENTIDE_VERSION"],
           env.isEmpty == false
        {
            return env
        }

        if let described = gitDescribe() {
            return described
        }

        return "0.0.0-dev"
    }

    private static func gitDescribe() -> String? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["describe", "--tags", "--always", "--dirty"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, text.isEmpty == false else {
            return nil
        }

        return text
    }

    private static func activityName(_ activity: AgentActivity) -> String {
        switch activity {
        case .working:
            "working"

        case .idle:
            "idle"

        case .done:
            "done"

        case .blocked:
            "blocked"
        }
    }

    private static func errorMessage(for error: Error) -> String {
        if error is DecodingError {
            return "invalid JSON"
        }

        return error.localizedDescription
    }

    private static func decode(_ line: String) throws -> Command {
        guard let data = line.data(using: .utf8) else {
            throw CoreError.invalidUTF8
        }

        return try JSONDecoder().decode(Command.self, from: data)
    }

    private static func emit(_ value: some Encodable) throws {
        let data = try JSONEncoder().encode(value)
        guard let line = String(data: data, encoding: .utf8) else {
            throw CoreError.invalidUTF8
        }

        print(line)
        fflush(stdout)
    }
}
