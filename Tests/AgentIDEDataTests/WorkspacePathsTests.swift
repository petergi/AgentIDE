@testable import AgentIDEData
import Foundation
import Testing

/// The shared workspace roots a first launch has to create.
struct WorkspacePathsTests {
    @Test
    func `ensureCreated makes the checkout and worktree directories`() throws {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("agentide-paths-" + UUID().uuidString)
            .path
        defer { try? FileManager.default.removeItem(atPath: root) }
        let paths = WorkspacePaths(
            hostUser: "tester",
            sharedWorkspace: root,
            sandboxHome: root + "/home",
            metadataFile: root + "/agentide/metadata.json",
        )

        #expect(FileManager.default.fileExists(atPath: paths.repositoriesDirectory) == false)
        try paths.ensureCreated()
        #expect(FileManager.default.fileExists(atPath: paths.repositoriesDirectory))
        #expect(FileManager.default.fileExists(atPath: paths.worktreesDirectory))
        #expect(FileManager.default.fileExists(atPath: paths.promptsDirectory))
    }
}
