import Foundation

public enum AccessMode: String, Codable, Sendable, Equatable {
    case read
    case readwrite
}

public struct Folder: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var path: String
    public var alias: String
    public var mode: AccessMode
    public var paused: Bool
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        path: String,
        alias: String,
        mode: AccessMode = .read,
        paused: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.alias = alias
        self.mode = mode
        self.paused = paused
        self.addedAt = addedAt
    }
}

public struct FoldersFile: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var folders: [Folder]

    public init(version: Int = FoldersFile.currentVersion, folders: [Folder] = []) {
        self.version = version
        self.folders = folders
    }
}
