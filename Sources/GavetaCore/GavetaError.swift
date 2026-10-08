import Foundation

public enum GavetaError: Error, Equatable, LocalizedError, Sendable {
    case invalidPath
    case outsideAllowedFolders
    case notFound
    case readOnlyFolder
    case storeUnreadable(String)
    case unsupportedVersion(Int)
    case storeWriteFailed(String)
    case pathDoesNotExist(String)
    case notADirectory(String)
    case forbiddenFolder(String)
    case alreadyCovered(path: String, by: String)
    case alreadyShared(alias: String)
    case invalidAlias(String)
    case aliasInUse(String)
    case folderNotFound(String)
    case isDirectory(String)
    case notARegularFile(String)
    case binaryFile(String)
    case invalidArgument(String)
    case readFailed(String)
    case needsAdministrator(command: String)
    case notASymlink(String)
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .needsAdministrator(let command):
            "Permission denied. Run it with administrator rights:\n  \(command)"
        case .notASymlink(let path):
            "\(path) exists and is not a symbolic link; refusing to replace it."
        case .installFailed(let detail):
            "Could not complete the operation: \(detail)"
        case .isDirectory(let path):
            "The path is a folder, not a file: \(path)"
        case .notARegularFile(let path):
            "The path is not a regular file: \(path)"
        case .binaryFile(let path):
            "The file is not text (binary or not UTF-8) and cannot be read: \(path)"
        case .invalidArgument(let detail):
            "Invalid argument: \(detail)"
        case .readFailed(let detail):
            "Could not read: \(detail)"
        case .pathDoesNotExist(let path):
            "The path does not exist: \(path)"
        case .notADirectory(let path):
            "The path is not a folder: \(path)"
        case .forbiddenFolder(let path):
            "This folder cannot be shared for security reasons: \(path)"
        case .alreadyCovered(let path, let by):
            "The folder \(path) is already covered by the shared folder \"\(by)\"."
        case .alreadyShared(let alias):
            "This folder is already shared as \"\(alias)\"."
        case .invalidAlias(let alias):
            "Invalid alias: \"\(alias)\". Use a short name without \"/\" that does not start with \".\" or \"~\"."
        case .aliasInUse(let alias):
            "The alias \"\(alias)\" is already in use. Pick another with --alias."
        case .folderNotFound(let identifier):
            "No shared folder matches \"\(identifier)\"."
        case .invalidPath:
            "Invalid path."
        case .outsideAllowedFolders:
            "Access denied: the path is outside the shared folders."
        case .notFound:
            "File or folder not found."
        case .readOnlyFolder:
            "Access denied: the folder is shared as read-only."
        case .storeUnreadable(let detail):
            "Could not read the list of shared folders: \(detail)"
        case .unsupportedVersion(let version):
            "Unsupported folders file version: \(version)."
        case .storeWriteFailed(let detail):
            "Could not save the list of shared folders: \(detail)"
        }
    }
}
