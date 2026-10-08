import Foundation
import Testing
@testable import GavetaCore

@Suite("PathDisplay")
struct PathDisplayTests {
    // Directory URLs carry a trailing slash, as `homeDirectoryForCurrentUser` does.
    let home = URL(filePath: "/Users/alice", directoryHint: .isDirectory)

    @Test func abbreviatesPathsInsideHome() {
        #expect(PathDisplay.abbreviate("/Users/alice/Desktop/x", home: home) == "~/Desktop/x")
        #expect(PathDisplay.abbreviate("/Users/alice", home: home) == "~")
    }

    @Test func leavesOtherPathsAlone() {
        #expect(PathDisplay.abbreviate("/Users/alice2/x", home: home) == "/Users/alice2/x")
        #expect(PathDisplay.abbreviate("/tmp/x", home: home) == "/tmp/x")
    }

    @Test func worksWithTheRealHomeDirectory() {
        let real = FileManager.default.homeDirectoryForCurrentUser
        #expect(PathDisplay.abbreviate(real.path + "/Desktop", home: real) == "~/Desktop")
    }
}
