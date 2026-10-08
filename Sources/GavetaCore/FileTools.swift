import Foundation

public enum EntryType: String, Codable, Sendable, Equatable {
    case file, directory, symlink, other
}

public struct FileEntry: Codable, Sendable, Equatable {
    public let name: String
    /// `alias/relative/path`, ready to pass to the other tools.
    public let path: String
    public let type: EntryType
    public let size: Int64
    public let modified: Date?
}

public struct DirectoryListing: Codable, Sendable, Equatable {
    public let path: String
    public let entries: [FileEntry]
    public let truncated: Bool
}

public struct FileSlice: Codable, Sendable, Equatable {
    public let path: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let truncated: Bool
    /// Line to pass as `offset` to continue reading, when truncated.
    public let nextOffset: Int?
}

public struct FileMetadata: Codable, Sendable, Equatable {
    public let path: String
    public let folder: String
    public let type: EntryType
    public let size: Int64
    public let modified: Date?
    public let created: Date?
    public let permissions: String
    public let writable: Bool
}

/// Read-only operations behind the MCP tools. Every path goes through `AccessPolicy.resolveAllowed`.
public struct FileTools: Sendable {
    public static let maxReadBytes = 1_048_576
    public static let maxListEntries = 1_000
    public static let maxDepth = 3

    public let policy: AccessPolicy

    public init(policy: AccessPolicy) {
        self.policy = policy
    }

    // MARK: - list_dir

    public func listDir(path: String, recursive: Bool = false, includeHidden: Bool = false) throws -> DirectoryListing {
        let url = try policy.resolveAllowed(path)
        let canonical = url.path(percentEncoded: false)
        guard try Self.kind(of: canonical) == .directory else {
            throw GavetaError.notADirectory(policy.displayPath(for: canonical))
        }

        let display = policy.displayPath(for: canonical)
        var entries: [FileEntry] = []
        var truncated = false
        try walk(
            directory: canonical, display: display, depth: 1,
            maxDepth: recursive ? Self.maxDepth : 1, includeHidden: includeHidden,
            entries: &entries, truncated: &truncated, isRoot: true
        )
        return DirectoryListing(path: display, entries: entries, truncated: truncated)
    }

    private func walk(
        directory: String, display: String, depth: Int, maxDepth: Int, includeHidden: Bool,
        entries: inout [FileEntry], truncated: inout Bool, isRoot: Bool
    ) throws {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: directory).sorted()
        } catch {
            if isRoot { throw Self.readError(error, display: display) }
            return // unreadable subfolder: skip
        }

        for name in names where includeHidden || !name.hasPrefix(".") {
            if entries.count >= Self.maxListEntries {
                truncated = true
                return
            }
            let childPath = directory + "/" + name
            var info = Darwin.stat()
            guard lstat(childPath, &info) == 0 else { continue }
            let type = Self.entryType(info.st_mode)
            let childDisplay = display + "/" + name
            entries.append(FileEntry(
                name: name, path: childDisplay, type: type,
                size: type == .file ? Int64(info.st_size) : 0,
                modified: Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec))
            ))
            // Symlinked directories are listed but never followed.
            if type == .directory, depth < maxDepth {
                try walk(
                    directory: childPath, display: childDisplay, depth: depth + 1, maxDepth: maxDepth,
                    includeHidden: includeHidden, entries: &entries, truncated: &truncated, isRoot: false
                )
                if truncated { return }
            }
        }
    }

    // MARK: - read_file

    /// `offset` is the 1-based first line; `limit` is the maximum number of lines.
    public func readFile(path: String, offset: Int = 1, limit: Int? = nil) throws -> FileSlice {
        guard offset >= 1 else { throw GavetaError.invalidArgument("offset must be 1 or greater.") }
        if let limit, limit < 1 { throw GavetaError.invalidArgument("limit must be 1 or greater.") }

        let url = try policy.resolveAllowed(path)
        let canonical = url.path(percentEncoded: false)
        let display = policy.displayPath(for: canonical)
        switch try Self.kind(of: canonical) {
        case .file: break
        case .directory: throw GavetaError.isDirectory(display)
        default: throw GavetaError.notARegularFile(display)
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw Self.readError(error, display: display)
        }
        defer { try? handle.close() }

        let maxBytes = Self.maxReadBytes
        var pending = Data()
        var output = Data()
        var lineNumber = 1
        var emitted = 0
        var nextOffset: Int?

        /// Returns false once the slice is full.
        func consume(_ line: Data, newline: Bool) throws -> Bool {
            defer { lineNumber += 1 }
            guard lineNumber >= offset else { return true }
            let size = line.count + (newline ? 1 : 0)
            if let limit, emitted >= limit { nextOffset = lineNumber; return false }
            if output.count + size > maxBytes {
                guard emitted > 0 else {
                    throw GavetaError.readFailed("line \(lineNumber) exceeds the 1 MB limit: \(display)")
                }
                nextOffset = lineNumber
                return false
            }
            output.append(line)
            if newline { output.append(0x0A) }
            emitted += 1
            return true
        }

        var full = false
        do {
            read: while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
                if chunk.contains(0) { throw GavetaError.binaryFile(display) }
                pending.append(chunk)
                while let newline = pending.firstIndex(of: 0x0A) {
                    let line = pending[pending.startIndex..<newline]
                    let keepGoing = try consume(Data(line), newline: true)
                    pending.removeSubrange(pending.startIndex...newline)
                    if !keepGoing { full = true; break read }
                }
                if pending.count > maxBytes {
                    throw GavetaError.readFailed("line longer than the 1 MB limit: \(display)")
                }
            }
            if !full, !pending.isEmpty {
                if try !consume(pending, newline: false) { full = true }
            }
        } catch let error as GavetaError {
            throw error
        } catch {
            throw Self.readError(error, display: display)
        }

        guard let content = String(data: output, encoding: .utf8) else { throw GavetaError.binaryFile(display) }
        return FileSlice(
            path: display, content: content,
            startLine: offset, endLine: offset + emitted - 1,
            truncated: nextOffset != nil, nextOffset: nextOffset
        )
    }

    // MARK: - stat

    public func stat(path: String) throws -> FileMetadata {
        let url = try policy.resolveAllowed(path)
        let canonical = url.path(percentEncoded: false)
        let display = policy.displayPath(for: canonical)
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: canonical)
        } catch {
            throw Self.readError(error, display: display)
        }

        let type = try Self.kind(of: canonical)
        let permissions = (attributes[.posixPermissions] as? Int).map { String($0, radix: 8) } ?? ""
        let folder = policy.displayPath(for: canonical).split(separator: "/").first.map(String.init) ?? ""
        return FileMetadata(
            path: display, folder: folder, type: type,
            size: type == .file ? (attributes[.size] as? Int64 ?? 0) : 0,
            modified: attributes[.modificationDate] as? Date,
            created: attributes[.creationDate] as? Date,
            permissions: permissions,
            writable: (try? policy.resolveAllowed(path, access: .write)) != nil
        )
    }

    // MARK: - Helpers

    private static func kind(of canonicalPath: String) throws -> EntryType {
        var info = Darwin.stat()
        // The path is already canonical (no symlinks), so lstat equals stat.
        guard lstat(canonicalPath, &info) == 0 else { throw GavetaError.notFound }
        return entryType(info.st_mode)
    }

    private static func entryType(_ mode: mode_t) -> EntryType {
        switch mode & S_IFMT {
        case S_IFREG: .file
        case S_IFDIR: .directory
        case S_IFLNK: .symlink
        default: .other
        }
    }

    private static func readError(_ error: any Error, display: String) -> GavetaError {
        let code = (error as NSError).code
        let posix = (error as NSError).domain == NSPOSIXErrorDomain ? code : nil
        let cocoaDenied = (error as? CocoaError)?.code == .fileReadNoPermission
        if posix == Int(EPERM) || posix == Int(EACCES) || cocoaDenied {
            return .readFailed("macOS denied read permission for \(display). Grant access to the agent's app in System Settings › Privacy & Security.")
        }
        if (error as? CocoaError)?.code == .fileReadNoSuchFile { return .notFound }
        return .readFailed("\(display) (\(error.localizedDescription))")
    }
}
