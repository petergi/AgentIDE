import AgentIDEData
import AgentIDERuntime
import Foundation

/// Headless NDJSON bridge the Linux GTK UI (and tests) speak to.
/// Commands arrive one JSON object per line on stdin; replies are
/// one JSON object per line on stdout.
@main
@MainActor
enum AgentIDECore {
    // MARK: Internal

    static func main() {
        // Keep Runtime in the executable graph for the GTK poll loop.
        _ = AgentIDERuntime()

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
                    let roots = PlatformRoots.detect()
                    try Self.emit(
                        RootsReply(
                            ok: true,
                            hostUser: roots.hostUser,
                            sharedWorkspace: roots.sharedWorkspace,
                            sandboxHome: roots.sandboxHome,
                            metadataFile: roots.metadataFile,
                            sharedTemporaryDirectory: roots.sharedTemporaryDirectory,
                        ),
                    )

                case "quit":
                    try Self.emit(OkReply(ok: true))
                    return

                default:
                    try Self.emit(ErrorReply(ok: false, error: "unknown cmd: \(command.cmd)"))
                }
            } catch {
                try? Self.emit(ErrorReply(ok: false, error: String(describing: error)))
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

    private enum CoreError: Error {
        case invalidUTF8
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
