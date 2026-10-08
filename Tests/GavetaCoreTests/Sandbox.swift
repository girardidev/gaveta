import Foundation
@testable import GavetaCore

/// Temporary directory tree used by the security tests. Everything lives under a canonical root.
///
///     root/home/
///     root/site/{index.html, sub/deep.txt, link-in, link-out, link-dir-out, link-dangling}
///     root/site2/file.txt        (name shares a prefix with `site`)
///     root/outside/secret.txt
///     root/ro/readme.txt
///     root/rw/
///     root/Docs with spaces é/café ñ.txt
final class Sandbox {
    let root: String

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "gaveta-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = try PathCanonicalizer.canonicalize(base.path(percentEncoded: false))

        try mkdir("home")
        try mkdir("site/sub")
        try mkdir("site2")
        try mkdir("outside")
        try mkdir("ro")
        try mkdir("rw")
        try mkdir("Docs with spaces é")

        try write("site/index.html", "<html></html>")
        try write("site/sub/deep.txt", "deep")
        try write("site2/file.txt", "site2")
        try write("outside/secret.txt", "secret")
        try write("ro/readme.txt", "readme")
        try write("Docs with spaces é/café ñ.txt", "héllo")

        try link("site/link-in", to: "\(root)/site/sub/deep.txt")
        try link("site/link-out", to: "\(root)/outside/secret.txt")
        try link("site/link-dir-out", to: "\(root)/outside")
        try link("site/link-dangling", to: "\(root)/outside/not-yet.txt")
    }

    deinit {
        try? FileManager.default.removeItem(atPath: root)
    }

    func path(_ relative: String) -> String { "\(root)/\(relative)" }

    func folder(_ name: String, alias: String? = nil, mode: AccessMode = .read, paused: Bool = false) -> Folder {
        Folder(path: path(name), alias: alias ?? name, mode: mode, paused: paused)
    }

    func policy(_ folders: Folder...) -> AccessPolicy {
        AccessPolicy(folders: folders, home: URL(filePath: path("home")))
    }

    private func mkdir(_ relative: String) throws {
        try FileManager.default.createDirectory(atPath: path(relative), withIntermediateDirectories: true)
    }

    private func write(_ relative: String, _ content: String) throws {
        try content.write(toFile: path(relative), atomically: true, encoding: .utf8)
    }

    private func link(_ relative: String, to destination: String) throws {
        try FileManager.default.createSymbolicLink(atPath: path(relative), withDestinationPath: destination)
    }
}
