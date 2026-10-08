import Foundation
import Testing
@testable import GavetaCore

@Suite("FolderManager")
struct FolderManagerTests {
    let sb: Sandbox
    let manager: FolderManager

    init() throws {
        sb = try Sandbox()
        try FileManager.default.createDirectory(atPath: sb.path("home/Library"), withIntermediateDirectories: true)
        manager = FolderManager(
            store: FolderStore(fileURL: URL(filePath: sb.path("config/folders.json"))),
            home: URL(filePath: sb.path("home")),
            currentDirectory: URL(filePath: sb.root)
        )
    }

    @Test func addsFolderWithCanonicalPathDefaultAliasAndReadMode() throws {
        let result = try manager.add(path: sb.path("site/../site"))
        #expect(result.folder.path == sb.path("site"))
        #expect(result.folder.alias == "site")
        #expect(result.folder.mode == .read)
        #expect(result.warnings.isEmpty)
        #expect(try manager.list() == [result.folder])
    }

    @Test func resolvesRelativeAndTildePaths() throws {
        try FileManager.default.createDirectory(atPath: sb.path("home/proj"), withIntermediateDirectories: true)
        #expect(try manager.add(path: "site").folder.path == sb.path("site"))
        #expect(try manager.add(path: "~/proj").folder.path == sb.path("home/proj"))
    }

    @Test func storesResolvedSymlinkTarget() throws {
        try FileManager.default.createSymbolicLink(atPath: sb.path("alias-link"), withDestinationPath: sb.path("rw"))
        #expect(try manager.add(path: sb.path("alias-link")).folder.path == sb.path("rw"))
    }

    @Test func acceptsCustomAliasAndWriteMode() throws {
        let folder = try manager.add(path: sb.path("rw"), alias: "meu-site", mode: .readwrite).folder
        #expect(folder.alias == "meu-site")
        #expect(folder.mode == .readwrite)
    }

    @Test func refusesMissingPathAndFiles() {
        #expect(throws: GavetaError.pathDoesNotExist(sb.path("nope"))) { try manager.add(path: sb.path("nope")) }
        #expect(throws: GavetaError.notADirectory(sb.path("site/index.html"))) {
            try manager.add(path: sb.path("site/index.html"))
        }
    }

    @Test func refusesRootHomeAndSystemTrees() throws {
        let home = sb.path("home")
        for path in ["/", home, "~", "/System", "/System/Applications", "/Library", sb.path("home/Library"), "~/Library"] {
            #expect(throws: GavetaError.self, "\(path)") { try manager.add(path: path) }
        }
        #expect(try manager.list().isEmpty)
    }

    @Test func allowsOnlyObsidianVaultsInsideLibrary() throws {
        let documents = sb.path("home/Library/Mobile Documents/iCloud~md~obsidian/Documents")
        try FileManager.default.createDirectory(atPath: documents + "/Notes/sub", withIntermediateDirectories: true)

        #expect(try manager.add(path: documents + "/Notes").folder.alias == "Notes")
        // Anything else around it stays refused.
        #expect(throws: GavetaError.self) { try manager.add(path: documents) }
        #expect(throws: GavetaError.self) { try manager.add(path: sb.path("home/Library/Mobile Documents")) }
        #expect(throws: GavetaError.self) { try manager.add(path: sb.path("home/Library")) }
    }

    @Test func refusesFolderInsideAnAlreadySharedOne() throws {
        try manager.add(path: sb.path("site"))
        #expect(throws: GavetaError.alreadyCovered(path: sb.path("site/sub"), by: "site")) {
            try manager.add(path: sb.path("site/sub"))
        }
    }

    @Test func refusesSameFolderTwice() throws {
        try manager.add(path: sb.path("site"))
        #expect(throws: GavetaError.alreadyShared(alias: "site")) { try manager.add(path: sb.path("site")) }
    }

    @Test func warnsWhenNewFolderContainsAnExistingOne() throws {
        try manager.add(path: sb.path("site/sub"))
        let result = try manager.add(path: sb.path("site"), alias: "tudo")
        #expect(result.warnings.count == 1)
        #expect(try manager.list().count == 2)
    }

    @Test func siblingWithSamePrefixIsNotConsideredCovered() throws {
        try manager.add(path: sb.path("site"))
        _ = try manager.add(path: sb.path("site2"))
    }

    @Test func refusesDuplicateAndInvalidAliases() throws {
        try manager.add(path: sb.path("site"))
        #expect(throws: GavetaError.aliasInUse("Site")) { try manager.add(path: sb.path("rw"), alias: "Site") }
        for bad in ["", "a/b", ".oculto", "~x", String(repeating: "a", count: 65)] {
            #expect(throws: GavetaError.invalidAlias(bad)) { try manager.add(path: sb.path("rw"), alias: bad) }
        }
    }

    @Test func removesByAliasAndByPath() throws {
        try manager.add(path: sb.path("site"))
        try manager.add(path: sb.path("rw"))
        #expect(try manager.remove("site").alias == "site")
        #expect(try manager.remove(sb.path("rw")).alias == "rw")
        #expect(try manager.list().isEmpty)
        #expect(throws: GavetaError.folderNotFound("site")) { try manager.remove("site") }
    }

    @Test func pausesAndResumes() throws {
        try manager.add(path: sb.path("site"))
        #expect(try manager.setPaused("site", paused: true).paused)
        #expect(try manager.list()[0].paused)
        #expect(try !manager.setPaused("site", paused: false).paused)
        #expect(throws: GavetaError.folderNotFound("x")) { try manager.setPaused("x", paused: true) }
    }

    @Test func pausedFolderIsDeniedByPolicyImmediately() throws {
        try manager.add(path: sb.path("site"))
        let before = try manager.store.policy()
        _ = try before.resolveAllowed("site/index.html")
        try manager.setPaused("site", paused: true)
        let after = try manager.store.policy()
        #expect(throws: GavetaError.outsideAllowedFolders) { try after.resolveAllowed("site/index.html") }
    }
}
