import Foundation
import GavetaCore
import MCP
import Testing
@testable import GavetaMCP

@Suite("ToolHandler")
final class ToolHandlerTests {
    let root: String
    let store: FolderStore
    let logURL: URL
    let handler: ToolHandler

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "gaveta-mcp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = try PathCanonicalizer.canonicalize(base.path(percentEncoded: false))

        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: root + "/site/sub", withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: root + "/outside", withIntermediateDirectories: true)
        try "héllo\nworld\n".write(toFile: root + "/site/a.txt", atomically: true, encoding: .utf8)
        try "secret".write(toFile: root + "/outside/secret.txt", atomically: true, encoding: .utf8)
        try fileManager.createSymbolicLink(atPath: root + "/site/escape", withDestinationPath: root + "/outside/secret.txt")

        store = FolderStore(fileURL: URL(filePath: root + "/config/folders.json"))
        try store.save(FoldersFile(folders: [Folder(path: root + "/site", alias: "site")]))
        logURL = URL(filePath: root + "/logs/mcp.log")
        handler = ToolHandler(store: store, home: URL(filePath: root + "/home"), log: ActivityLog(fileURL: logURL))
    }

    deinit { try? FileManager.default.removeItem(atPath: root) }

    private func text(_ result: CallTool.Result) -> String {
        result.content.compactMap { content -> String? in
            if case .text(let text, _, _) = content { return text }
            return nil
        }.joined(separator: "\n")
    }

    @Test func exposesWriteToolOnlyWhileAReadWriteFolderIsActive() throws {
        let manager = FolderManager(store: store, home: URL(filePath: root + "/home"))
        #expect(handler.availableTools().map(\.name) == ["list_folders", "list_dir", "read_file", "stat", "search"])
        #expect(!handler.isWriteEnabled())
        #expect(handler.call(name: "write_file", arguments: ["path": "site/x.txt", "content": "x"]).isError == true)

        try FileManager.default.createDirectory(atPath: root + "/rw", withIntermediateDirectories: true)
        try manager.add(path: root + "/rw", mode: .readwrite)
        #expect(handler.availableTools().map(\.name).last == "write_file")

        try manager.setPaused("rw", paused: true)
        #expect(!handler.availableTools().map(\.name).contains("write_file"))
    }

    @Test func searchesAndWritesThroughTools() throws {
        let found = handler.call(name: "search", arguments: ["query": "world"])
        #expect(found.isError == false)
        #expect(text(found).contains("\"line\" : 2"))

        let manager = FolderManager(store: store, home: URL(filePath: root + "/home"))
        try FileManager.default.createDirectory(atPath: root + "/rw", withIntermediateDirectories: true)
        try manager.add(path: root + "/rw", mode: .readwrite)

        let wrote = handler.call(name: "write_file", arguments: ["path": "rw/new.txt", "content": "created"])
        #expect(wrote.isError == false)
        #expect(try String(contentsOfFile: root + "/rw/new.txt", encoding: .utf8) == "created")
        #expect(handler.call(name: "write_file", arguments: ["path": "site/new.txt", "content": "x"]).isError == true)
        #expect(handler.call(name: "write_file", arguments: ["path": "rw/../outside/x.txt", "content": "x"]).isError == true)
        #expect(handler.call(name: "write_file", arguments: ["path": "rw/n.txt"]).isError == true)
        #expect(handler.call(name: "search", arguments: ["query": ""]).isError == true)
    }

    @Test func listsFolders() {
        let result = handler.call(name: "list_folders", arguments: nil)
        #expect(result.isError == false)
        #expect(text(result).contains("\"alias\" : \"site\""))
        #expect(text(result).contains("\"mode\" : \"read\""))
    }

    @Test func listsDirectory() {
        let result = handler.call(name: "list_dir", arguments: ["path": "site"])
        #expect(result.isError == false)
        #expect(text(result).contains("site/a.txt"))
        #expect(!text(result).contains("outside"))
    }

    @Test func readsFileWithPaging() {
        let all = handler.call(name: "read_file", arguments: ["path": "site/a.txt"])
        #expect(text(all) == "héllo\nworld\n")
        let part = handler.call(name: "read_file", arguments: ["path": "site/a.txt", "limit": 1])
        #expect(text(part).hasPrefix("héllo\n"))
        #expect(text(part).contains("offset=2"))
    }

    @Test func statsPath() {
        let result = handler.call(name: "stat", arguments: ["path": "site/a.txt"])
        #expect(text(result).contains("\"type\" : \"file\""))
    }

    @Test func deniesEscapesWithAnErrorResult() {
        for path in ["site/escape", "site/../outside/secret.txt", root + "/outside/secret.txt", "~/.ssh/id_rsa"] {
            let result = handler.call(name: "read_file", arguments: ["path": .string(path)])
            #expect(result.isError == true, "\(path)")
            #expect(!text(result).contains("secret"))
        }
    }

    @Test func reportsBadArguments() {
        #expect(handler.call(name: "read_file", arguments: [:]).isError == true)
        #expect(handler.call(name: "read_file", arguments: ["path": 3]).isError == true)
        #expect(handler.call(name: "list_dir", arguments: ["path": "site", "recursive": "yes"]).isError == true)
        #expect(handler.call(name: "write_file", arguments: ["path": "site/x", "content": "y"]).isError == true)
    }

    @Test func pausingTakesEffectOnTheNextCall() throws {
        #expect(handler.call(name: "read_file", arguments: ["path": "site/a.txt"]).isError == false)
        try FolderManager(store: store, home: URL(filePath: root + "/home")).setPaused("site", paused: true)
        #expect(handler.call(name: "read_file", arguments: ["path": "site/a.txt"]).isError == true)
        #expect(text(handler.call(name: "list_folders", arguments: nil)).contains("\"folders\" : [\n\n  ]"))
        try FolderManager(store: store, home: URL(filePath: root + "/home")).setPaused("site", paused: false)
        #expect(handler.call(name: "read_file", arguments: ["path": "site/a.txt"]).isError == false)
    }

    @Test func removingAllFoldersDeniesEverything() throws {
        try store.save(FoldersFile())
        #expect(handler.call(name: "list_dir", arguments: ["path": "site"]).isError == true)
    }

    @Test func corruptStoreDeniesInsteadOfAllowing() throws {
        try "garbage".write(to: store.fileURL, atomically: true, encoding: .utf8)
        #expect(handler.call(name: "read_file", arguments: ["path": "site/a.txt"]).isError == true)
    }

    @Test func logsCallsWithoutFileContents() throws {
        _ = handler.call(name: "read_file", arguments: ["path": "site/a.txt"])
        _ = handler.call(name: "read_file", arguments: ["path": "site/escape"])
        let log = try String(contentsOf: logURL, encoding: .utf8)
        #expect(log.contains("read_file\tsite/a.txt\tok"))
        #expect(log.contains("read_file\tsite/escape\terror"))
        #expect(!log.contains("world"))
    }
}
