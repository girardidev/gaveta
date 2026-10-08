import Foundation
import GavetaCore
import Testing
@testable import GavetaApp

@MainActor
@Suite("FolderObserver")
struct FolderObserverTests {
    let directory: URL
    let store: FolderStore

    init() {
        directory = FileManager.default.temporaryDirectory.appending(path: "gaveta-app-\(UUID().uuidString)")
        store = FolderStore(fileURL: directory.appending(path: "folders.json"))
    }

    private func waitUntil(timeout: Duration = .seconds(1), _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    @Test func startsEmptyWhenThereIsNoFile() {
        defer { try? FileManager.default.removeItem(at: directory) }
        let observer = FolderObserver(store: store)
        #expect(observer.folders.isEmpty)
        #expect(observer.errorMessage == nil)
    }

    @Test func picksUpChangesFromTheFileWithinOneSecond() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let observer = FolderObserver(store: store)

        try store.save(FoldersFile(folders: [Folder(path: "/tmp/a", alias: "a")]))
        #expect(await waitUntil { observer.folders.map(\.alias) == ["a"] })

        try store.save(FoldersFile(folders: [Folder(path: "/tmp/a", alias: "a", paused: true), Folder(path: "/tmp/b", alias: "b")]))
        #expect(await waitUntil { observer.folders.count == 2 && observer.folders[0].paused })

        try store.save(FoldersFile())
        #expect(await waitUntil { observer.folders.isEmpty })
    }

    @Test func pausingWritesTheFile() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.save(FoldersFile(folders: [Folder(path: "/tmp/a", alias: "a")]))
        let observer = FolderObserver(store: store)
        observer.setPaused(observer.folders[0], paused: true)
        #expect(observer.folders[0].paused)
        #expect(try store.load().folders[0].paused)
    }

    @Test func reportsAnUnreadableFileAndRecovers() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.save(FoldersFile(folders: [Folder(path: "/tmp/a", alias: "a")]))
        let observer = FolderObserver(store: store)

        try "garbage".write(to: store.fileURL, atomically: true, encoding: .utf8)
        #expect(await waitUntil { observer.errorMessage != nil })
        #expect(observer.folders.isEmpty)

        try store.save(FoldersFile(folders: [Folder(path: "/tmp/a", alias: "a")]))
        #expect(await waitUntil { observer.errorMessage == nil && observer.folders.count == 1 })
    }
}
