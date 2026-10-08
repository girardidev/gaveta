import Foundation

/// Changes the list of shared folders. CLI and app go through this; they never validate on their own.
public struct FolderManager: Sendable {
    public struct AddResult: Sendable, Equatable {
        public let folder: Folder
        public let warnings: [String]
    }

    public let store: FolderStore
    public let home: URL
    /// Base for relative paths passed to `add`.
    public let currentDirectory: URL

    public init(
        store: FolderStore = FolderStore(),
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDirectory: URL = URL(filePath: FileManager.default.currentDirectoryPath)
    ) {
        self.store = store
        self.home = home
        self.currentDirectory = currentDirectory
    }

    public func list() throws -> [Folder] {
        try store.load().folders
    }

    @discardableResult
    public func add(path: String, alias: String? = nil, mode: AccessMode = .read) throws -> AddResult {
        let canonical = try canonicalDirectory(path)
        try rejectForbidden(canonical)

        var file = try store.load()
        let components = PathCanonicalizer.comparableComponents(canonical)

        for existing in file.folders {
            let existingComponents = PathCanonicalizer.comparableComponents(existing.path)
            if existingComponents == components {
                throw GavetaError.alreadyShared(alias: existing.alias)
            }
            if Self.isInside(components, of: existingComponents) {
                throw GavetaError.alreadyCovered(path: canonical, by: existing.alias)
            }
        }

        let finalAlias = try validatedAlias(alias ?? Self.lastComponent(of: canonical), existing: file.folders)

        var warnings: [String] = []
        for existing in file.folders {
            if Self.isInside(PathCanonicalizer.comparableComponents(existing.path), of: components) {
                warnings.append("The already shared folder \"\(existing.alias)\" is inside this one and is now covered by it.")
            }
        }

        // Whole seconds: the JSON stores ISO 8601 without fractions.
        let addedAt = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let folder = Folder(path: canonical, alias: finalAlias, mode: mode, addedAt: addedAt)
        file.folders.append(folder)
        try store.save(file)
        return AddResult(folder: folder, warnings: warnings)
    }

    /// `identifier` is an alias or a path.
    @discardableResult
    public func remove(_ identifier: String) throws -> Folder {
        var file = try store.load()
        guard let index = index(of: identifier, in: file.folders) else {
            throw GavetaError.folderNotFound(identifier)
        }
        let removed = file.folders.remove(at: index)
        try store.save(file)
        return removed
    }

    @discardableResult
    public func setPaused(_ alias: String, paused: Bool) throws -> Folder {
        var file = try store.load()
        let key = alias.precomposedStringWithCanonicalMapping.lowercased()
        guard let index = file.folders.firstIndex(where: {
            $0.alias.precomposedStringWithCanonicalMapping.lowercased() == key
        }) else {
            throw GavetaError.folderNotFound(alias)
        }
        file.folders[index].paused = paused
        try store.save(file)
        return file.folders[index]
    }

    // MARK: - Validation

    private func canonicalDirectory(_ input: String) throws -> String {
        guard !input.isEmpty, !input.contains("\0") else { throw GavetaError.invalidPath }
        let absolute = absolutePath(input)
        let canonical: String
        do {
            canonical = try PathCanonicalizer.canonicalize(absolute)
        } catch .notFound {
            throw GavetaError.pathDoesNotExist(absolute)
        } catch {
            throw GavetaError.invalidPath
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: canonical, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw GavetaError.notADirectory(canonical)
        }
        return canonical
    }

    private func absolutePath(_ input: String) -> String {
        let homePath = home.path(percentEncoded: false)
        if input == "~" { return homePath }
        if input.hasPrefix("~/") { return homePath + "/" + input.dropFirst(2) }
        if input.hasPrefix("/") { return input }
        return currentDirectory.path(percentEncoded: false) + "/" + input
    }

    /// Refuses `/`, the whole home, and the system/library trees (and anything inside them).
    private func rejectForbidden(_ canonical: String) throws {
        let components = PathCanonicalizer.comparableComponents(canonical)
        let homeComponents = PathCanonicalizer.comparableComponents(
            (try? PathCanonicalizer.canonicalize(home.path(percentEncoded: false))) ?? home.path(percentEncoded: false)
        )
        let isRootOrHome = components.isEmpty || components == homeComponents
        let blockedTrees = [["System"], ["Library"], homeComponents + ["Library"]]
        // Only exception inside ~/Library: Obsidian vaults in iCloud (children of its Documents folder).
        let obsidianDocuments = homeComponents + ["Library", "Mobile Documents", "iCloud~md~obsidian", "Documents"]
        let isObsidianVault = components.count > obsidianDocuments.count && Self.isInside(components, of: obsidianDocuments)
        if !isObsidianVault,
           isRootOrHome || blockedTrees.contains(where: { Self.isInside(components, of: $0) }) {
            throw GavetaError.forbiddenFolder(canonical)
        }
    }

    private func validatedAlias(_ alias: String, existing: [Folder]) throws -> String {
        let normalized = alias.precomposedStringWithCanonicalMapping
        let hasControl = normalized.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        guard !normalized.isEmpty, normalized.count <= 64, !hasControl,
              !normalized.contains("/"), !normalized.hasPrefix("."), !normalized.hasPrefix("~") else {
            throw GavetaError.invalidAlias(alias)
        }
        let key = normalized.lowercased()
        if existing.contains(where: { $0.alias.precomposedStringWithCanonicalMapping.lowercased() == key }) {
            throw GavetaError.aliasInUse(normalized)
        }
        return normalized
    }

    private func index(of identifier: String, in folders: [Folder]) -> Int? {
        let key = identifier.precomposedStringWithCanonicalMapping.lowercased()
        if let byAlias = folders.firstIndex(where: {
            $0.alias.precomposedStringWithCanonicalMapping.lowercased() == key
        }) {
            return byAlias
        }
        let candidate = (try? PathCanonicalizer.canonicalize(absolutePath(identifier))) ?? absolutePath(identifier)
        let components = PathCanonicalizer.comparableComponents(candidate)
        return folders.firstIndex { PathCanonicalizer.comparableComponents($0.path) == components }
    }

    // MARK: - Helpers

    /// True when `path` equals or is below `root`, compared by components.
    static func isInside(_ path: [String], of root: [String]) -> Bool {
        path.count >= root.count && Array(path[..<root.count]) == root
    }

    private static func lastComponent(of path: String) -> String {
        PathCanonicalizer.splitComponents(path).last ?? path
    }
}
