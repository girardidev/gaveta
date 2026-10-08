import Foundation
import Testing
@testable import GavetaMCP

@Suite("Version")
struct VersionTests {
    @Test func versionFileMatchesTheServerVersion() throws {
        let file = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "VERSION")
        let version = try String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(version == GavetaServer.version)
    }
}
