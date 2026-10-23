import Foundation

/// Aliases a single MCP server instance may expose. It only narrows `folders.json`:
/// a folder outside the registry, or paused, is never made visible by being listed here.
public struct FolderScope: Sendable, Equatable {
    public let aliases: [String]
    private let normalized: Set<String>

    public init(aliases: [String]) {
        self.aliases = aliases
        self.normalized = Set(aliases.map(Self.normalize))
    }

    public func matches(_ folder: Folder) -> Bool {
        normalized.contains(Self.normalize(folder.alias))
    }

    /// Aliases that do not match any active (not paused) folder.
    public func unresolved(in folders: [Folder]) -> [String] {
        let active = Set(folders.filter { !$0.paused }.map { Self.normalize($0.alias) })
        return aliases.filter { !active.contains(Self.normalize($0)) }
    }

    private static func normalize(_ alias: String) -> String {
        alias.precomposedStringWithCanonicalMapping
    }
}
