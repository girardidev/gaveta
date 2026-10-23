import Foundation
import Testing
@testable import GavetaCore

@Suite("FolderScope")
struct FolderScopeTests {
    private func policy(
        _ sandbox: Sandbox, scope: FolderScope?, folders: [Folder]
    ) throws -> AccessPolicy {
        let store = FolderStore(fileURL: URL(filePath: sandbox.path("config/folders.json")))
        try store.save(FoldersFile(folders: folders))
        return try store.policy(home: URL(filePath: sandbox.path("home")), scope: scope)
    }

    @Test func keepsOnlyListedFolders() throws {
        let sandbox = try Sandbox()
        let policy = try policy(
            sandbox, scope: FolderScope(aliases: ["site"]),
            folders: [sandbox.folder("site"), sandbox.folder("ro")]
        )
        #expect(policy.activeFolders.map(\.alias) == ["site"])
        #expect(throws: GavetaError.self) { try policy.resolveAllowed("ro/readme.txt") }
    }

    @Test func absoluteAndHomePathsOutsideTheScopeAreDenied() throws {
        let sandbox = try Sandbox()
        let policy = try policy(
            sandbox, scope: FolderScope(aliases: ["site"]),
            folders: [sandbox.folder("site"), sandbox.folder("ro")]
        )
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sandbox.path("ro/readme.txt")) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sandbox.path("ro/missing.txt")) }
        _ = try policy.resolveAllowed(sandbox.path("site/index.html"))
    }

    @Test func pausedFolderStaysInvisibleEvenWhenListed() throws {
        let sandbox = try Sandbox()
        let policy = try policy(
            sandbox, scope: FolderScope(aliases: ["site"]),
            folders: [sandbox.folder("site", paused: true)]
        )
        #expect(policy.activeFolders.isEmpty)
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/index.html") }
    }

    @Test func unsharedAliasGrantsNothing() throws {
        let sandbox = try Sandbox()
        let policy = try policy(
            sandbox, scope: FolderScope(aliases: ["outside"]), folders: [sandbox.folder("site")]
        )
        #expect(policy.activeFolders.isEmpty)
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sandbox.path("outside/secret.txt")) }
    }

    @Test func matchesAliasesAcrossUnicodeNormalization() throws {
        let sandbox = try Sandbox()
        let decomposed = "Cafe\u{301}"
        let precomposed = "Caf\u{E9}"
        let policy = try policy(
            sandbox, scope: FolderScope(aliases: [decomposed]),
            folders: [sandbox.folder("site", alias: precomposed)]
        )
        #expect(policy.activeFolders.map(\.alias) == [precomposed])
    }

    @Test func nilScopeKeepsEveryFolder() throws {
        let sandbox = try Sandbox()
        let policy = try policy(sandbox, scope: nil, folders: [sandbox.folder("site"), sandbox.folder("ro")])
        #expect(policy.activeFolders.map(\.alias) == ["site", "ro"])
    }

    @Test func reportsAliasesWithoutAnActiveFolder() throws {
        let sandbox = try Sandbox()
        let scope = FolderScope(aliases: ["site", "ro", "typo"])
        let folders = [sandbox.folder("site"), sandbox.folder("ro", paused: true)]
        #expect(scope.unresolved(in: folders) == ["ro", "typo"])
    }
}
