import Foundation
import Testing
@testable import GavetaCore

@Suite("Glob")
struct GlobTests {
    @Test(arguments: [
        ("*.swift", "a.swift", true),
        ("*.swift", "src/a.swift", true), // no slash: matches the file name
        ("*.swift", "a.swiftx", false),
        ("src/*.swift", "src/a.swift", true),
        ("src/*.swift", "src/deep/a.swift", false),
        ("src/**/*.swift", "src/a.swift", true),
        ("src/**/*.swift", "src/x/y/a.swift", true),
        ("**/*.md", "README.md", true),
        ("*.{md,txt}", "a.txt", true),
        ("*.{md,txt}", "a.rs", false),
        ("a?c.txt", "abc.txt", true),
        ("a?c.txt", "a/c.txt", false),
        ("a+b(1).txt", "a+b(1).txt", true),
    ])
    func matches(pattern: String, path: String, expected: Bool) throws {
        #expect(try Glob(pattern).matches(path) == expected)
    }

    @Test func rejectsUnbalancedBraces() {
        #expect(throws: GavetaError.self) { try Glob("*.{md,txt") }
    }
}

@Suite("search and write_file")
struct SearchAndWriteTests {
    let sb: Sandbox
    let tools: FileTools

    init() throws {
        sb = try Sandbox()
        tools = FileTools(policy: sb.policy(sb.folder("site"), sb.folder("rw", mode: .readwrite)))
    }

    private func put(_ relative: String, _ content: String) throws {
        let url = URL(filePath: sb.path(relative))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }

    // MARK: - search

    @Test func findsLinesAcrossAllFoldersCaseInsensitively() throws {
        try put("site/notes.md", "First\nThere is a TEST here\nend")
        try put("rw/b.txt", "another test")
        let result = try tools.search(query: "test")
        #expect(result.matches.contains(SearchMatch(path: "site/notes.md", line: 2, text: "There is a TEST here")))
        #expect(result.matches.contains(SearchMatch(path: "rw/b.txt", line: 1, text: "another test")))
        #expect(!result.truncated && !result.incomplete)
    }

    @Test func honorsCaseSensitiveFlag() throws {
        try put("rw/c.txt", "Test\ntest")
        #expect(try tools.search(query: "Test", caseSensitive: true).matches.map(\.line) == [1])
    }

    @Test func matchesFileNames() throws {
        try put("rw/report-final.txt", "nothing")
        let match = try #require(try tools.search(query: "report").matches.first)
        #expect(match == SearchMatch(path: "rw/report-final.txt", line: nil, text: nil))
    }

    @Test func restrictsToFolderAndSubpath() throws {
        try put("site/a.txt", "needle")
        try put("rw/sub/b.txt", "needle")
        #expect(try tools.search(query: "needle", folder: "rw").matches.map(\.path) == ["rw/sub/b.txt"])
        #expect(try tools.search(query: "needle", folder: "rw/sub").matches.map(\.path) == ["rw/sub/b.txt"])
    }

    @Test func filtersByGlob() throws {
        try put("rw/a.swift", "needle")
        try put("rw/b.md", "needle")
        try put("rw/src/c.swift", "needle")
        #expect(try tools.search(query: "needle", folder: "rw", glob: "*.swift").matches.map(\.path) == ["rw/a.swift", "rw/src/c.swift"])
        #expect(try tools.search(query: "needle", folder: "rw", glob: "src/**").matches.map(\.path) == ["rw/src/c.swift"])
    }

    @Test func skipsIgnoredBinaryAndSymlinks() throws {
        try put("rw/.git/config", "needle")
        try put("rw/node_modules/pkg/i.js", "needle")
        try put("rw/.DS_Store", "needle")
        try Data([0x6E, 0x65, 0x00, 0x65, 0x64, 0x6C, 0x65]).write(to: URL(filePath: sb.path("rw/bin.dat")))
        try Data([0x6E, 0x65, 0x65, 0x64, 0x6C, 0x65, 0xE9]).write(to: URL(filePath: sb.path("rw/latin1.txt")))
        try put("rw/ok.txt", "needle")
        #expect(try tools.search(query: "needle").matches.map(\.path) == ["rw/ok.txt"])
    }

    @Test func neverFollowsSymlinksOutOfTheFolder() throws {
        // site/link-out and site/link-dir-out point at outside/secret.txt; it contains "secret".
        let result = try tools.search(query: "secret")
        #expect(result.matches.isEmpty)
    }

    @Test func capsAtTwoHundredResults() throws {
        try put("rw/many.txt", (0..<500).map { "hit \($0)" }.joined(separator: "\n"))
        let result = try tools.search(query: "hit")
        #expect(result.matches.count == 200)
        #expect(result.truncated)
    }

    @Test func truncatesLongLines() throws {
        try put("rw/long.txt", "needle " + String(repeating: "x", count: 1_000))
        let text = try #require(try tools.search(query: "needle").matches.first?.text)
        #expect(text.count == 300)
    }

    @Test func searchDeniesOutsideFoldersAndPausedOnes() throws {
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.search(query: "x", folder: sb.path("outside")) }
        let paused = FileTools(policy: sb.policy(sb.folder("rw", paused: true)))
        #expect(throws: GavetaError.outsideAllowedFolders) { try paused.search(query: "x") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try paused.search(query: "x", folder: "rw") }
    }

    @Test func searchValidatesArguments() {
        #expect(throws: GavetaError.self) { try tools.search(query: "") }
        #expect(throws: GavetaError.self) { try tools.search(query: "x", glob: "*.{a") }
    }

    @Test func nestedFoldersAreNotSearchedTwice() throws {
        try put("site/sub/n.txt", "needle")
        let nested = FileTools(policy: sb.policy(sb.folder("site"), Folder(path: sb.path("site/sub"), alias: "sub")))
        #expect(try nested.search(query: "needle").matches.count == 1)
    }

    // MARK: - write_file

    @Test func createsNewFileAtomically() throws {
        let result = try tools.writeFile(path: "rw/fresh.txt", content: "héllo ñ\n")
        #expect(result == WriteResult(path: "rw/fresh.txt", bytesWritten: 10, created: true))
        #expect(try String(contentsOfFile: sb.path("rw/fresh.txt"), encoding: .utf8) == "héllo ñ\n")
        let entries = try FileManager.default.contentsOfDirectory(atPath: sb.path("rw"))
        #expect(entries == ["fresh.txt"])
    }

    @Test func overwritesAndKeepsPermissions() throws {
        try put("rw/run.sh", "old")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sb.path("rw/run.sh"))
        let result = try tools.writeFile(path: "rw/run.sh", content: "new")
        #expect(!result.created)
        #expect(try String(contentsOfFile: sb.path("rw/run.sh"), encoding: .utf8) == "new")
        let mode = try FileManager.default.attributesOfItem(atPath: sb.path("rw/run.sh"))[.posixPermissions] as? Int
        #expect(mode == 0o755)
    }

    @Test func refusesWritesOutsideReadWriteFolders() throws {
        #expect(throws: GavetaError.readOnlyFolder) { try tools.writeFile(path: "site/x.txt", content: "x") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.writeFile(path: "rw/../outside/x.txt", content: "x") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.writeFile(path: sb.path("outside/x.txt"), content: "x") }
        #expect(!FileManager.default.fileExists(atPath: sb.path("site/x.txt")))
        #expect(!FileManager.default.fileExists(atPath: sb.path("outside/x.txt")))
    }

    @Test func refusesSymlinkEscapesOnWrite() throws {
        try FileManager.default.createSymbolicLink(atPath: sb.path("rw/out"), withDestinationPath: sb.path("outside/secret.txt"))
        try FileManager.default.createSymbolicLink(atPath: sb.path("rw/outdir"), withDestinationPath: sb.path("outside"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.writeFile(path: "rw/out", content: "pwned") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.writeFile(path: "rw/outdir/new.txt", content: "pwned") }
        #expect(try String(contentsOfFile: sb.path("outside/secret.txt"), encoding: .utf8) == "secret")
    }

    @Test func refusesDirectoriesMissingParentsAndHugeContent() throws {
        try put("rw/dir/x.txt", "x")
        #expect(throws: GavetaError.isDirectory("rw/dir")) { try tools.writeFile(path: "rw/dir", content: "x") }
        #expect(throws: GavetaError.self) { try tools.writeFile(path: "rw/nope/x.txt", content: "x") }
        let huge = String(repeating: "a", count: FileTools.maxWriteBytes + 1)
        #expect(throws: GavetaError.self) { try tools.writeFile(path: "rw/huge.txt", content: huge) }
    }

    @Test func writesThroughSymlinkInsideTheFolder() throws {
        try put("rw/real.txt", "old")
        try FileManager.default.createSymbolicLink(atPath: sb.path("rw/link"), withDestinationPath: sb.path("rw/real.txt"))
        _ = try tools.writeFile(path: "rw/link", content: "new")
        #expect(try String(contentsOfFile: sb.path("rw/real.txt"), encoding: .utf8) == "new")
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: sb.path("rw/link"))) != nil)
    }
}
