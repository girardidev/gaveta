import Foundation

/// Reads and writes `folders.json`, the single source of truth shared by CLI, app and MCP server.
public struct FolderStore: Sendable {
    public let fileURL: URL

    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Gaveta/folders.json")
    }

    public init(fileURL: URL = FolderStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    /// A missing file means no folders. A present but unreadable file throws,
    /// so callers deny access instead of guessing.
    public func load() throws -> FoldersFile {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return FoldersFile()
        } catch {
            throw GavetaError.storeUnreadable(error.localizedDescription)
        }

        let file: FoldersFile
        do {
            file = try Self.makeDecoder().decode(FoldersFile.self, from: data)
        } catch {
            throw GavetaError.storeUnreadable("Invalid JSON (\(error.localizedDescription))")
        }
        guard file.version == FoldersFile.currentVersion else {
            throw GavetaError.unsupportedVersion(file.version)
        }
        return file
    }

    /// Writes atomically (temporary file + rename) so readers never see a partial file.
    public func save(_ file: FoldersFile) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.makeEncoder().encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw GavetaError.storeWriteFailed(error.localizedDescription)
        }
    }

    public func policy(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> AccessPolicy {
        AccessPolicy(folders: try load().folders, home: home)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
