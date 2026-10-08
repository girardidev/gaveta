import Foundation
import Testing
@testable import GavetaCore

@Suite("resolveAllowed")
struct AccessPolicyTests {
    let sb: Sandbox

    init() throws { sb = try Sandbox() }

    // MARK: - Basics

    @Test func allowsFileInsideFolderByAbsolutePath() throws {
        let policy = sb.policy(sb.folder("site"))
        let url = try policy.resolveAllowed(sb.path("site/index.html"))
        #expect(url.path(percentEncoded: false) == sb.path("site/index.html"))
    }

    @Test func allowsFileInsideFolderByAlias() throws {
        let policy = sb.policy(sb.folder("site"))
        let url = try policy.resolveAllowed("site/sub/deep.txt")
        #expect(url.path(percentEncoded: false) == sb.path("site/sub/deep.txt"))
    }

    @Test func allowsFolderRootItself() throws {
        let policy = sb.policy(sb.folder("site"))
        #expect(try policy.resolveAllowed("site").path(percentEncoded: false) == sb.path("site"))
        #expect(try policy.resolveAllowed(sb.path("site")).path(percentEncoded: false) == sb.path("site"))
    }

    @Test func deniesWhenNoFoldersAreShared() {
        let policy = sb.policy()
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sb.path("site/index.html")) }
    }

    // MARK: - Escaping with ..

    @Test func deniesDotDotEscapeWithAbsolutePath() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) {
            try policy.resolveAllowed(sb.path("site/../outside/secret.txt"))
        }
    }

    @Test func deniesDotDotEscapeWithAlias() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/../outside/secret.txt") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/sub/../../outside/secret.txt") }
    }

    @Test func allowsDotDotThatStaysInside() throws {
        let policy = sb.policy(sb.folder("site"))
        let url = try policy.resolveAllowed("site/sub/../index.html")
        #expect(url.path(percentEncoded: false) == sb.path("site/index.html"))
    }

    @Test func deniesSensitiveHomeFileByAnyTrick() {
        let policy = sb.policy(sb.folder("site"))
        for attempt in ["~/.ssh/id_rsa", "~root/.ssh/id_rsa", "site/../home/.ssh/id_rsa", "/etc/passwd", "../../etc/passwd", ".ssh/id_rsa"] {
            #expect(throws: GavetaError.self) { try policy.resolveAllowed(attempt) }
        }
    }

    // MARK: - Symlinks

    @Test func deniesSymlinkToFileOutside() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/link-out") }
    }

    @Test func deniesPathThroughSymlinkedDirectoryOutside() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/link-dir-out/secret.txt") }
    }

    @Test func allowsSymlinkInsideTargetingInside() throws {
        let policy = sb.policy(sb.folder("site"))
        let url = try policy.resolveAllowed("site/link-in")
        #expect(url.path(percentEncoded: false) == sb.path("site/sub/deep.txt"))
    }

    @Test func deniesFolderRootThatWasSwappedForSymlinkOutside() throws {
        let swapped = sb.path("swapped")
        try FileManager.default.createSymbolicLink(atPath: swapped, withDestinationPath: sb.path("outside"))
        let folder = Folder(path: swapped, alias: "swapped")
        // The stored path resolves to `outside`; the check uses the canonical root,
        // so files there are allowed only as `outside`, never via another folder.
        let policy = sb.policy(folder, sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sb.path("site2/file.txt")) }
    }

    // MARK: - Prefix lookalikes

    @Test func deniesSiblingWithSamePrefix() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sb.path("site2/file.txt")) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/../site2/file.txt") }
    }

    // MARK: - Paused

    @Test func pausedFolderBehavesAsNonexistent() {
        let policy = sb.policy(sb.folder("site", paused: true))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sb.path("site/index.html")) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/index.html") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site") }
    }

    @Test func pausedFolderDoesNotBlockAnotherActiveFolderContainingThePath() throws {
        let nested = Folder(path: sb.path("site/sub"), alias: "sub", paused: true)
        let policy = sb.policy(sb.folder("site"), nested)
        _ = try policy.resolveAllowed(sb.path("site/sub/deep.txt"))
    }

    // MARK: - Not found vs denied

    @Test func missingPathInsideFolderIsNotFound() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.notFound) { try policy.resolveAllowed("site/nope/missing.txt") }
    }

    @Test func danglingSymlinkIsDeniedNotReportedAsMissing() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/link-dangling") }
    }

    @Test func missingPathOutsideFoldersLooksLikeAnyOtherDenial() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed(sb.path("outside/nope.txt")) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("/definitely/not/here") }
    }

    // MARK: - Write

    @Test func deniesWriteInReadOnlyFolder() {
        let policy = sb.policy(sb.folder("ro"))
        #expect(throws: GavetaError.readOnlyFolder) { try policy.resolveAllowed("ro/new.txt", access: .write) }
        #expect(throws: GavetaError.readOnlyFolder) { try policy.resolveAllowed("ro/readme.txt", access: .write) }
    }

    @Test func allowsWriteOfNewFileInReadWriteFolder() throws {
        let policy = sb.policy(sb.folder("rw", mode: .readwrite))
        let url = try policy.resolveAllowed("rw/new.txt", access: .write)
        #expect(url.path(percentEncoded: false) == sb.path("rw/new.txt"))
    }

    @Test func allowsWriteOfExistingFileInReadWriteFolder() throws {
        let policy = sb.policy(sb.folder("site", mode: .readwrite))
        _ = try policy.resolveAllowed("site/index.html", access: .write)
    }

    @Test func deniesWriteWhoseParentEscapes() {
        let policy = sb.policy(sb.folder("rw", mode: .readwrite))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("rw/../outside/new.txt", access: .write) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("rw/../ro/new.txt", access: .write) }
    }

    @Test func deniesWriteThroughSymlinks() {
        let policy = sb.policy(sb.folder("site", mode: .readwrite))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/link-out", access: .write) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/link-dir-out/new.txt", access: .write) }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("site/link-dangling", access: .write) }
    }

    @Test func deniesWriteWhenParentDoesNotExist() {
        let policy = sb.policy(sb.folder("rw", mode: .readwrite))
        #expect(throws: GavetaError.self) { try policy.resolveAllowed("rw/missing-dir/new.txt", access: .write) }
    }

    @Test func deniesWriteWithInvalidFinalComponent() {
        let policy = sb.policy(sb.folder("rw", mode: .readwrite))
        #expect(throws: GavetaError.invalidPath) { try policy.resolveAllowed("rw/..", access: .write) }
        #expect(throws: GavetaError.invalidPath) { try policy.resolveAllowed("rw/.", access: .write) }
    }

    @Test func readWriteFolderInsideReadOnlyFolderAllowsWriteOnlyThere() throws {
        let policy = sb.policy(sb.folder("site"), Folder(path: sb.path("site/sub"), alias: "sub", mode: .readwrite))
        _ = try policy.resolveAllowed(sb.path("site/sub/new.txt"), access: .write)
        #expect(throws: GavetaError.readOnlyFolder) { try policy.resolveAllowed(sb.path("site/new.txt"), access: .write) }
    }

    // MARK: - Unicode, spaces, tilde, invalid input

    @Test func allowsUnicodeAndSpaces() throws {
        let policy = sb.policy(sb.folder("Docs with spaces é", alias: "docs"))
        let url = try policy.resolveAllowed("docs/café ñ.txt")
        #expect(url.path(percentEncoded: false).hasSuffix("café ñ.txt"))
        _ = try policy.resolveAllowed(sb.path("Docs with spaces é/café ñ.txt"))
    }

    @Test func treatsComposedAndDecomposedUnicodeAsEqual() throws {
        let policy = sb.policy(sb.folder("Docs with spaces é", alias: "docs"))
        let decomposedFolder = "Docs with spaces é".decomposedStringWithCanonicalMapping
        let decomposedFile = "café ñ.txt".decomposedStringWithCanonicalMapping
        _ = try policy.resolveAllowed("\(sb.root)/\(decomposedFolder)/\(decomposedFile)")
        _ = try policy.resolveAllowed("docs/\(decomposedFile)")
    }

    @Test func expandsTildeToConfiguredHome() throws {
        try FileManager.default.createDirectory(atPath: sb.path("home/proj"), withIntermediateDirectories: true)
        try "x".write(toFile: sb.path("home/proj/a.txt"), atomically: true, encoding: .utf8)
        let policy = sb.policy(Folder(path: sb.path("home/proj"), alias: "proj"))
        _ = try policy.resolveAllowed("~/proj/a.txt")
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("~") }
    }

    @Test func rejectsInvalidInput() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.invalidPath) { try policy.resolveAllowed("") }
        #expect(throws: GavetaError.invalidPath) { try policy.resolveAllowed("site/index.html\0.png") }
    }

    @Test func rejectsRelativePathThatIsNotAnAlias() {
        let policy = sb.policy(sb.folder("site"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("index.html") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("./site/index.html") }
    }

    @Test func neverHonorsRootAsAFolder() {
        let policy = sb.policy(Folder(path: "/", alias: "root"))
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("/etc/hosts") }
        #expect(throws: GavetaError.outsideAllowedFolders) { try policy.resolveAllowed("root/etc/hosts") }
    }
}
