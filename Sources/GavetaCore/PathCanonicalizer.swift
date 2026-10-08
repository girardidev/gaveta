import Foundation

/// Canonical path resolution built on `realpath(3)`, which resolves `..` and symlinks.
public enum PathCanonicalizer {
    public enum Failure: Error, Equatable, Sendable {
        case notFound
        case other
    }

    /// Resolves `path` to its canonical absolute form, including the on-disk letter case.
    public static func canonicalize(_ path: String) throws(Failure) -> String {
        guard let raw = realpath(path, nil) else {
            throw errno == ENOENT ? .notFound : .other
        }
        defer { free(raw) }
        let resolved = String(cString: raw)
        return onDiskCase(of: resolved) ?? resolved
    }

    /// Canonical form of the deepest ancestor of `path` that exists.
    /// Also returns `missing`, the path one component deeper; if that entry exists (a dangling
    /// symlink), the path is not simply "missing" and callers must not report it as such.
    static func nearestExistingAncestor(of path: String) -> (canonical: String, missing: String)? {
        let all = splitComponents(path)
        var components = all
        while !components.isEmpty {
            components.removeLast()
            let candidate = "/" + components.joined(separator: "/")
            if let canonical = try? canonicalize(candidate) {
                return (canonical, "/" + all.prefix(components.count + 1).joined(separator: "/"))
            }
        }
        return nil
    }

    /// Path components, NFC-normalized so composed and decomposed Unicode compare equal.
    static func comparableComponents(_ path: String) -> [String] {
        splitComponents(path).map { $0.precomposedStringWithCanonicalMapping }
    }

    static func splitComponents(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    /// `realpath` keeps the caller's letter case on case-insensitive volumes;
    /// `F_GETPATH` returns the real one, so comparisons stay exact.
    private static func onDiskCase(of path: String) -> String? {
        // O_NONBLOCK: opening a FIFO must never hang the server.
        let fd = open(path, O_EVTONLY | O_NONBLOCK)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard fcntl(fd, F_GETPATH, &buffer) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
