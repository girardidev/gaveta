import Foundation
import Testing
@testable import GavetaCore

@Suite("FileTools")
struct FileToolsTests {
    let sb: Sandbox
    let tools: FileTools

    init() throws {
        sb = try Sandbox()
        tools = FileTools(policy: sb.policy(sb.folder("site"), sb.folder("rw", mode: .readwrite)))
    }

    private func write(_ relative: String, _ data: Data) throws {
        try data.write(to: URL(filePath: sb.path(relative)))
    }

    // MARK: - list_dir

    @Test func listsDirectoryWithAliasPaths() throws {
        let listing = try tools.listDir(path: "site")
        #expect(listing.path == "site")
        #expect(listing.entries.map(\.name) == ["index.html", "link-dangling", "link-dir-out", "link-in", "link-out", "sub"])
        let index = try #require(listing.entries.first { $0.name == "index.html" })
        #expect(index.path == "site/index.html")
        #expect(index.type == .file)
        #expect(index.size == 13)
        #expect(listing.entries.first { $0.name == "sub" }?.type == .directory)
        #expect(listing.entries.first { $0.name == "link-out" }?.type == .symlink)
    }

    @Test func hidesDotFilesUnlessAsked() throws {
        try write("site/.env", Data("x".utf8))
        #expect(try !tools.listDir(path: "site").entries.contains { $0.name == ".env" })
        #expect(try tools.listDir(path: "site", includeHidden: true).entries.contains { $0.name == ".env" })
    }

    @Test func recursiveStopsAtDepthThree() throws {
        try FileManager.default.createDirectory(atPath: sb.path("rw/a/b/c/d"), withIntermediateDirectories: true)
        try write("rw/a/b/c/d/deep.txt", Data("x".utf8))
        let paths = try tools.listDir(path: "rw", recursive: true).entries.map(\.path)
        #expect(paths == ["rw/a", "rw/a/b", "rw/a/b/c"])
        #expect(try tools.listDir(path: "rw").entries.map(\.path) == ["rw/a"])
    }

    @Test func recursiveDoesNotFollowSymlinkedDirectories() throws {
        let paths = try tools.listDir(path: "site", recursive: true).entries.map(\.path)
        #expect(paths.contains("site/link-dir-out"))
        #expect(!paths.contains { $0.hasPrefix("site/link-dir-out/") })
    }

    @Test func truncatesAtOneThousandEntries() throws {
        for index in 0..<1_005 { try write("rw/f\(index).txt", Data()) }
        let listing = try tools.listDir(path: "rw")
        #expect(listing.entries.count == 1_000)
        #expect(listing.truncated)
    }

    @Test func listDirRejectsFilesAndOutsidePaths() {
        #expect(throws: GavetaError.self) { try tools.listDir(path: "site/index.html") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.listDir(path: sb.path("outside")) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.listDir(path: "site/link-dir-out") }
    }

    // MARK: - read_file

    @Test func readsWholeFile() throws {
        try write("rw/a.txt", Data("one\ntwo\nthree\n".utf8))
        let slice = try tools.readFile(path: "rw/a.txt")
        #expect(slice.content == "one\ntwo\nthree\n")
        #expect(slice.startLine == 1 && slice.endLine == 3)
        #expect(!slice.truncated && slice.nextOffset == nil)
    }

    @Test func readsFileWithoutTrailingNewline() throws {
        try write("rw/a.txt", Data("one\ntwo".utf8))
        #expect(try tools.readFile(path: "rw/a.txt").content == "one\ntwo")
    }

    @Test func paginatesWithOffsetAndLimit() throws {
        try write("rw/a.txt", Data((1...10).map { "line \($0)\n" }.joined().utf8))
        let first = try tools.readFile(path: "rw/a.txt", offset: 3, limit: 2)
        #expect(first.content == "line 3\nline 4\n")
        #expect(first.startLine == 3 && first.endLine == 4)
        #expect(first.truncated && first.nextOffset == 5)
        let last = try tools.readFile(path: "rw/a.txt", offset: 9, limit: 5)
        #expect(last.content == "line 9\nline 10\n")
        #expect(!last.truncated)
        #expect(try tools.readFile(path: "rw/a.txt", offset: 50).content.isEmpty)
    }

    @Test func capsAtOneMegabyteAndContinues() throws {
        let line = String(repeating: "x", count: 99) + "\n"
        try write("rw/big.txt", Data(String(repeating: line, count: 20_000).utf8)) // 2 MB
        let slice = try tools.readFile(path: "rw/big.txt")
        #expect(slice.content.utf8.count <= FileTools.maxReadBytes)
        #expect(slice.truncated)
        let next = try tools.readFile(path: "rw/big.txt", offset: try #require(slice.nextOffset))
        #expect(next.startLine == slice.endLine + 1)
    }

    @Test func refusesBinaryAndInvalidUTF8() throws {
        try write("rw/bin.dat", Data([0x50, 0x4B, 0x00, 0x03]))
        try write("rw/latin1.txt", Data([0x61, 0xE9, 0x0A]))
        #expect(throws: GavetaError.binaryFile("rw/bin.dat")) { try tools.readFile(path: "rw/bin.dat") }
        #expect(throws: GavetaError.binaryFile("rw/latin1.txt")) { try tools.readFile(path: "rw/latin1.txt") }
    }

    @Test func readFileRejectsDirectoriesFifosAndEscapes() throws {
        #expect(throws: GavetaError.isDirectory("site/sub")) { try tools.readFile(path: "site/sub") }
        #expect(mkfifo(sb.path("rw/pipe"), 0o600) == 0)
        #expect(throws: GavetaError.notARegularFile("rw/pipe")) { try tools.readFile(path: "rw/pipe") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.readFile(path: "site/link-out") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.readFile(path: "~/.ssh/id_rsa") }
        #expect(throws: GavetaError.notFound) { try tools.readFile(path: "site/missing.txt") }
    }

    @Test func readFileValidatesArguments() {
        #expect(throws: GavetaError.self) { try tools.readFile(path: "site/index.html", offset: 0) }
        #expect(throws: GavetaError.self) { try tools.readFile(path: "site/index.html", limit: 0) }
    }

    @Test func readsFollowingSymlinkInside() throws {
        #expect(try tools.readFile(path: "site/link-in").content == "deep")
    }

    // MARK: - stat

    @Test func statsFileAndFolder() throws {
        let file = try tools.stat(path: "site/index.html")
        #expect(file.type == .file && file.size == 13 && file.folder == "site" && !file.writable)
        #expect(try tools.stat(path: "rw").writable)
        #expect(try tools.stat(path: "site/sub").type == .directory)
        #expect(throws: GavetaError.outsideAllowedFolders) { try tools.stat(path: sb.path("outside/secret.txt")) }
    }

    @Test func displayPathPrefersMostSpecificFolder() throws {
        let policy = sb.policy(sb.folder("site"), Folder(path: sb.path("site/sub"), alias: "sub"))
        #expect(policy.displayPath(for: sb.path("site/sub/deep.txt")) == "sub/deep.txt")
        #expect(policy.displayPath(for: sb.path("site/index.html")) == "site/index.html")
    }
}
