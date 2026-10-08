import Foundation

public enum Access: Sendable, Equatable {
    case read
    case write
}

/// The only place that decides whether a path may be touched.
/// Every tool must go through `resolveAllowed`; it denies by default.
public struct AccessPolicy: Sendable {
    public let folders: [Folder]
    public let home: URL

    public init(folders: [Folder], home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.folders = folders
        self.home = home
    }

    /// Returns the canonical URL for `input` (absolute, `~`, or `alias/sub/path`) or throws.
    public func resolveAllowed(_ input: String, access: Access = .read) throws -> URL {
        let expanded = try expand(input)
        switch access {
        case .read: return URL(filePath: try resolveForRead(expanded))
        case .write: return URL(filePath: try resolveForWrite(expanded))
        }
    }

    /// Folders visible to agents (paused ones behave as nonexistent).
    public var activeFolders: [Folder] { folders.filter { !$0.paused } }

    /// `alias/relative/path` form of an already canonical path, accepted back by `resolveAllowed`.
    public func displayPath(for canonical: String) -> String {
        let target = PathCanonicalizer.comparableComponents(canonical)
        var best: (folder: Folder, count: Int)?
        for folder in activeFolders {
            guard let root = try? PathCanonicalizer.canonicalize(folder.path) else { continue }
            let rootComponents = PathCanonicalizer.comparableComponents(root)
            guard !rootComponents.isEmpty, target.count >= rootComponents.count,
                  Array(target[..<rootComponents.count]) == rootComponents else { continue }
            if rootComponents.count > (best?.count ?? -1) { best = (folder, rootComponents.count) }
        }
        guard let best else { return canonical }
        let rest = PathCanonicalizer.splitComponents(canonical).dropFirst(best.count)
        return ([best.folder.alias] + rest).joined(separator: "/")
    }

    // MARK: - Expansion

    private func expand(_ input: String) throws -> String {
        guard !input.isEmpty, !input.contains("\0") else { throw GavetaError.invalidPath }

        if input.hasPrefix("/") { return input }

        if input.hasPrefix("~") {
            if input == "~" { return home.path(percentEncoded: false) }
            guard input.hasPrefix("~/") else { throw GavetaError.outsideAllowedFolders }
            return home.path(percentEncoded: false) + "/" + input.dropFirst(2)
        }

        let parts = input.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let alias = String(parts[0]).precomposedStringWithCanonicalMapping
        guard let folder = folders.first(where: {
            !$0.paused && $0.alias.precomposedStringWithCanonicalMapping == alias
        }) else {
            throw GavetaError.outsideAllowedFolders
        }
        let rest = parts.count > 1 ? String(parts[1]) : ""
        return rest.isEmpty ? folder.path : folder.path + "/" + rest
    }

    // MARK: - Read

    private func resolveForRead(_ path: String) throws -> String {
        let canonical: String
        do {
            canonical = try PathCanonicalizer.canonicalize(path)
        } catch .notFound {
            // Only reveal "not found" when the nearest existing ancestor is allowed;
            // otherwise a missing path outside the folders must look like any other denial.
            // A dangling symlink also lands here; its target must not be revealed as missing.
            if let ancestor = PathCanonicalizer.nearestExistingAncestor(of: path),
               !lexists(ancestor.missing),
               evaluate(ancestor.canonical, access: .read) == .allowed {
                throw GavetaError.notFound
            }
            throw GavetaError.outsideAllowedFolders
        } catch {
            throw GavetaError.outsideAllowedFolders
        }
        guard evaluate(canonical, access: .read) == .allowed else {
            throw GavetaError.outsideAllowedFolders
        }
        return canonical
    }

    // MARK: - Write

    private func resolveForWrite(_ path: String) throws -> String {
        let trimmed = trimTrailingSlashes(path)
        guard let slash = trimmed.lastIndex(of: "/") else { throw GavetaError.invalidPath }
        let name = String(trimmed[trimmed.index(after: slash)...])
        guard !name.isEmpty, name != ".", name != ".." else { throw GavetaError.invalidPath }

        let target: String
        if lexists(trimmed) {
            // Existing entry (including a symlink): resolve it fully. A dangling symlink
            // fails here and is denied, since writing through it could create a file elsewhere.
            do {
                target = try PathCanonicalizer.canonicalize(trimmed)
            } catch {
                throw GavetaError.outsideAllowedFolders
            }
        } else {
            let parentPath = slash == trimmed.startIndex ? "/" : String(trimmed[..<slash])
            let parent: String
            do {
                parent = try PathCanonicalizer.canonicalize(parentPath)
            } catch {
                throw GavetaError.outsideAllowedFolders
            }
            target = (parent == "/" ? "" : parent) + "/" + name
        }

        switch evaluate(target, access: .write) {
        case .allowed: return target
        case .readOnly: throw GavetaError.readOnlyFolder
        case .denied: throw GavetaError.outsideAllowedFolders
        }
    }

    // MARK: - Evaluation

    private enum Decision { case allowed, readOnly, denied }

    /// `canonical` must already be canonicalized. Compares path components, never string prefixes.
    private func evaluate(_ canonical: String, access: Access) -> Decision {
        let target = PathCanonicalizer.comparableComponents(canonical)
        var insideReadOnly = false

        for folder in folders where !folder.paused {
            guard let root = try? PathCanonicalizer.canonicalize(folder.path) else { continue }
            let rootComponents = PathCanonicalizer.comparableComponents(root)
            guard !rootComponents.isEmpty else { continue } // never honor "/" as a folder
            guard target.count >= rootComponents.count,
                  Array(target[..<rootComponents.count]) == rootComponents else { continue }

            if access == .read || folder.mode == .readwrite { return .allowed }
            insideReadOnly = true
        }
        return insideReadOnly ? .readOnly : .denied
    }

    private func trimTrailingSlashes(_ path: String) -> String {
        var result = path
        while result.count > 1, result.hasSuffix("/") { result.removeLast() }
        return result
    }

    private func lexists(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0
    }
}
