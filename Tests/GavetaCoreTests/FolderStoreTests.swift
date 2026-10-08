import Foundation
import Testing
@testable import GavetaCore

@Suite("FolderStore")
struct FolderStoreTests {
    let dir: URL
    let store: FolderStore

    init() throws {
        dir = FileManager.default.temporaryDirectory.appending(path: "gaveta-store-\(UUID().uuidString)")
        store = FolderStore(fileURL: dir.appending(path: "nested/folders.json"))
    }

    @Test func missingFileMeansNoFolders() throws {
        #expect(try store.load() == FoldersFile())
    }

    @Test func roundTripsAndCreatesDirectories() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let folder = Folder(
            path: "/Users/x/Projetos/site", alias: "site", mode: .readwrite, paused: true,
            addedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        try store.save(FoldersFile(folders: [folder]))
        #expect(try store.load().folders == [folder])
    }

    @Test func writesDocumentedJSONShape() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let folder = Folder(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            path: "/Users/x/site", alias: "site",
            addedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        try store.save(FoldersFile(folders: [folder]))
        let json = try String(contentsOf: store.fileURL, encoding: .utf8)
        #expect(json.contains("\"version\" : 1"))
        #expect(json.contains("\"mode\" : \"read\""))
        #expect(json.contains("\"paused\" : false"))
        #expect(json.contains("\"path\" : \"/Users/x/site\""))
        #expect(json.contains("\"addedAt\" : \"2026-"))
    }

    @Test func overwritesAtomicallyWithoutLeavingTemporaryFiles() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        try store.save(FoldersFile(folders: [Folder(path: "/a", alias: "a")]))
        try store.save(FoldersFile(folders: [Folder(path: "/b", alias: "b")]))
        #expect(try store.load().folders.map(\.alias) == ["b"])
        let entries = try FileManager.default.contentsOfDirectory(atPath: store.fileURL.deletingLastPathComponent().path)
        #expect(entries == ["folders.json"])
    }

    @Test func corruptFileThrowsInsteadOfBeingTreatedAsEmpty() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{ not json".write(to: store.fileURL, atomically: true, encoding: .utf8)
        #expect(throws: GavetaError.self) { try store.load() }
    }

    @Test func unsupportedVersionThrows() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"version": 99, "folders": []}"#.write(to: store.fileURL, atomically: true, encoding: .utf8)
        #expect(throws: GavetaError.unsupportedVersion(99)) { try store.load() }
    }
}
