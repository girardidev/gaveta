import Foundation

public struct WriteResult: Codable, Sendable, Equatable {
    public let path: String
    public let bytesWritten: Int
    public let created: Bool
}

extension FileTools {
    public static let maxWriteBytes = 1_048_576

    /// Creates or overwrites a text file inside a `readwrite` folder. The parent directory must exist.
    public func writeFile(path: String, content: String) throws -> WriteResult {
        let data = Data(content.utf8)
        guard data.count <= Self.maxWriteBytes else {
            throw GavetaError.invalidArgument("the content exceeds the 1 MB per-write limit.")
        }

        let url = try policy.resolveAllowed(path, access: .write)
        let canonical = url.path(percentEncoded: false)
        let display = policy.displayPath(for: canonical)

        var info = Darwin.stat()
        let exists = lstat(canonical, &info) == 0
        if exists {
            switch info.st_mode & S_IFMT {
            case S_IFREG: break
            case S_IFDIR: throw GavetaError.isDirectory(display)
            default: throw GavetaError.notARegularFile(display)
            }
        }

        do {
            // .atomic writes a temporary file and renames it, so readers never see half a file.
            try data.write(to: url, options: .atomic)
            if exists {
                try FileManager.default.setAttributes([.posixPermissions: Int(info.st_mode & 0o7777)], ofItemAtPath: canonical)
            }
        } catch {
            throw GavetaError.readFailed("failed to write \(display) (\(error.localizedDescription))")
        }
        return WriteResult(path: display, bytesWritten: data.count, created: !exists)
    }
}
