import Foundation
import GavetaCore
import MCP

/// Maps MCP tool calls onto `FileTools`. The folder list is reloaded on every call,
/// so adding, removing or pausing a folder takes effect immediately.
public struct ToolHandler: Sendable {
    public let store: FolderStore
    public let home: URL
    public let log: ActivityLog

    public init(
        store: FolderStore = FolderStore(),
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        log: ActivityLog = ActivityLog()
    ) {
        self.store = store
        self.home = home
        self.log = log
    }

    // MARK: - Tool definitions

    public static let tools: [Tool] = [
        Tool(
            name: "list_folders",
            description: "List the folders the user has shared with you (alias, absolute path and access mode). Start here. Paths in other tools can be absolute or `alias/sub/path`.",
            inputSchema: schema([:]),
            annotations: readOnly
        ),
        Tool(
            name: "list_dir",
            description: "List the entries of a shared directory (name, type, size, modification date). Up to 1000 entries.",
            inputSchema: schema([
                "path": .object(["type": "string", "description": "Directory: absolute path or `alias/sub/path`."]),
                "recursive": .object(["type": "boolean", "description": "Also list subdirectories, up to depth 3. Default false."]),
                "include_hidden": .object(["type": "boolean", "description": "Include entries starting with a dot. Default false."]),
            ], required: ["path"]),
            annotations: readOnly
        ),
        Tool(
            name: "read_file",
            description: "Read a UTF-8 text file from a shared folder. Returns at most 1 MB per call; use `offset` and `limit` (in lines) to page through larger files. Binary files are refused.",
            inputSchema: schema([
                "path": .object(["type": "string", "description": "File: absolute path or `alias/sub/file.txt`."]),
                "offset": .object(["type": "integer", "description": "First line to return, 1-based. Default 1."]),
                "limit": .object(["type": "integer", "description": "Maximum number of lines to return."]),
            ], required: ["path"]),
            annotations: readOnly
        ),
        Tool(
            name: "stat",
            description: "Get metadata of a file or directory in a shared folder: type, size, dates, permissions and whether it is writable.",
            inputSchema: schema([
                "path": .object(["type": "string", "description": "Absolute path or `alias/sub/path`."]),
            ], required: ["path"]),
            annotations: readOnly
        ),
        Tool(
            name: "search",
            description: "Search text in file names and file contents of the shared folders (literal match, case-insensitive by default). Returns up to 200 matches as path, line number and line text. Skips .git, node_modules, .DS_Store, symlinks and binary files.",
            inputSchema: schema([
                "query": .object(["type": "string", "description": "Text to look for (not a regex)."]),
                "folder": .object(["type": "string", "description": "Restrict to one folder: alias, `alias/sub/path` or absolute path. Default: all shared folders."]),
                "glob": .object(["type": "string", "description": "Only search files matching this glob, e.g. `*.swift` (file name) or `src/**/*.ts` (path inside the folder)."]),
                "case_sensitive": .object(["type": "boolean", "description": "Default false."]),
            ], required: ["query"]),
            annotations: readOnly
        ),
    ]

    /// Only offered while at least one active folder is `readwrite`.
    public static let writeTool = Tool(
        name: "write_file",
        description: "Create or overwrite a UTF-8 text file (max 1 MB) inside a shared folder that allows writing. The parent directory must already exist. Only folders marked readwrite accept writes.",
        inputSchema: schema([
            "path": .object(["type": "string", "description": "File: absolute path or `alias/sub/file.txt`."]),
            "content": .object(["type": "string", "description": "Full new content of the file."]),
        ], required: ["path", "content"]),
        annotations: Tool.Annotations(readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false)
    )

    /// True when the current `folders.json` has an active `readwrite` folder.
    public func isWriteEnabled() -> Bool {
        guard let file = try? store.load() else { return false }
        return file.folders.contains { !$0.paused && $0.mode == .readwrite }
    }

    /// Reloaded on every `tools/list`, so `write_file` appears only while it can work.
    public func availableTools() -> [Tool] {
        isWriteEnabled() ? Self.tools + [Self.writeTool] : Self.tools
    }

    private static let readOnly = Tool.Annotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)

    private static func schema(_ properties: [String: Value], required: [String] = []) -> Value {
        var object: [String: Value] = ["type": "object", "properties": .object(properties)]
        if !required.isEmpty { object["required"] = .array(required.map { .string($0) }) }
        return .object(object)
    }

    // MARK: - Dispatch

    public func call(name: String, arguments: [String: Value]?) -> CallTool.Result {
        let target = arguments?["path"]?.stringValue
        do {
            let result = try dispatch(name: name, arguments: arguments ?? [:])
            log.record(tool: name, target: target, outcome: "ok")
            return result
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            log.record(tool: name, target: target, outcome: "error: \(message)")
            return CallTool.Result(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
        }
    }

    private func dispatch(name: String, arguments: [String: Value]) throws -> CallTool.Result {
        let policy = try store.policy(home: home)
        let files = FileTools(policy: policy)

        switch name {
        case "list_folders":
            let folders = policy.activeFolders.map { FolderInfo(alias: $0.alias, path: $0.path, mode: $0.mode) }
            return try json(["folders": folders])

        case "list_dir":
            let listing = try files.listDir(
                path: try requiredString("path", in: arguments),
                recursive: try optionalBool("recursive", in: arguments) ?? false,
                includeHidden: try optionalBool("include_hidden", in: arguments) ?? false
            )
            return try json(listing)

        case "read_file":
            let slice = try files.readFile(
                path: try requiredString("path", in: arguments),
                offset: try optionalInt("offset", in: arguments) ?? 1,
                limit: try optionalInt("limit", in: arguments)
            )
            var content: [Tool.Content] = [.text(text: slice.content, annotations: nil, _meta: nil)]
            if let next = slice.nextOffset {
                let note = "[Truncated after line \(slice.endLine). Continue with offset=\(next).]"
                content.append(.text(text: note, annotations: nil, _meta: nil))
            }
            return CallTool.Result(content: content, isError: false)

        case "stat":
            return try json(try files.stat(path: try requiredString("path", in: arguments)))

        case "search":
            return try json(try files.search(
                query: try requiredString("query", in: arguments),
                folder: arguments["folder"]?.isNull == false ? try requiredString("folder", in: arguments) : nil,
                glob: arguments["glob"]?.isNull == false ? try requiredString("glob", in: arguments) : nil,
                caseSensitive: try optionalBool("case_sensitive", in: arguments) ?? false
            ))

        case "write_file":
            guard policy.activeFolders.contains(where: { $0.mode == .readwrite }) else {
                throw GavetaError.invalidArgument("unknown tool: write_file")
            }
            return try json(try files.writeFile(
                path: try requiredString("path", in: arguments),
                content: try requiredString("content", in: arguments)
            ))

        default:
            throw GavetaError.invalidArgument("unknown tool: \(name)")
        }
    }

    // MARK: - Helpers

    private struct FolderInfo: Codable {
        let alias: String
        let path: String
        let mode: AccessMode
    }

    private func json<T: Encodable>(_ value: T) throws -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let text = String(decoding: try encoder.encode(value), as: UTF8.self)
        return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
    }

    private func requiredString(_ key: String, in arguments: [String: Value]) throws -> String {
        guard let value = arguments[key]?.stringValue else {
            throw GavetaError.invalidArgument("\"\(key)\" is required and must be text.")
        }
        return value
    }

    private func optionalBool(_ key: String, in arguments: [String: Value]) throws -> Bool? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let bool = value.boolValue else { throw GavetaError.invalidArgument("\"\(key)\" must be a boolean.") }
        return bool
    }

    private func optionalInt(_ key: String, in arguments: [String: Value]) throws -> Int? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let int = value.intValue else { throw GavetaError.invalidArgument("\"\(key)\" must be an integer.") }
        return int
    }
}
