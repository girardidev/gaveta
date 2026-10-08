import Foundation

/// Appends one line per tool call to `~/Library/Logs/Gaveta/mcp.log`. Never writes file contents,
/// and never touches stdout (reserved for the MCP protocol).
public final class ActivityLog: @unchecked Sendable {
    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Gaveta/mcp.log")
    }

    private let fileURL: URL?
    private let lock = NSLock()

    /// Pass `nil` to disable logging.
    public init(fileURL: URL? = ActivityLog.defaultFileURL) {
        self.fileURL = fileURL
    }

    public func record(tool: String, target: String?, outcome: String) {
        guard let fileURL else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = [timestamp, tool, target ?? "-", outcome]
            .map { $0.replacingOccurrences(of: "\n", with: " ") }
            .joined(separator: "\t") + "\n"

        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            FileHandle.standardError.write(Data("gaveta: could not write the log: \(error.localizedDescription)\n".utf8))
        }
    }
}
