import Foundation

public enum MCPClient: String, CaseIterable, Sendable {
    case claudeDesktop = "claude-desktop"
    case claudeCode = "claude-code"
    case cursor
    case opencode

    public var displayName: String {
        switch self {
        case .claudeDesktop: "Claude Desktop"
        case .claudeCode: "Claude Code"
        case .cursor: "Cursor"
        case .opencode: "OpenCode"
        }
    }

    /// Where the user pastes the snippet.
    public var configHint: String {
        switch self {
        case .claudeDesktop: "~/Library/Application Support/Claude/claude_desktop_config.json"
        case .claudeCode: ".mcp.json in the project root (or ~/.claude.json)"
        case .cursor: "~/.cursor/mcp.json (or .cursor/mcp.json in the project)"
        case .opencode: "~/.config/opencode/opencode.json (or opencode.json in the project)"
        }
    }
}

public enum ClientConfig {
    public static let installedPath = "/usr/local/bin/gaveta"

    /// Prefers the stable installed symlink; otherwise the given executable.
    public static func preferredExecutable(fallback: String) -> String {
        FileManager.default.isExecutableFile(atPath: installedPath) ? installedPath : fallback
    }

    /// Arguments for `gaveta`: `mcp`, then `--folder <alias>` for each folder the project may see.
    public static func arguments(folders: [String] = []) -> [String] {
        ["mcp"] + folders.flatMap { ["--folder", $0] }
    }

    /// JSON snippet to paste into the client's MCP configuration.
    public static func json(for client: MCPClient, executable: String, folders: [String] = []) -> String {
        let args = arguments(folders: folders)
        let object: [String: Any]
        switch client {
        case .claudeDesktop, .cursor:
            object = ["mcpServers": ["gaveta": ["command": executable, "args": args]]]
        case .claudeCode:
            object = ["mcpServers": ["gaveta": ["type": "stdio", "command": executable, "args": args]]]
        case .opencode:
            object = [
                "$schema": "https://opencode.ai/config.json",
                "mcp": ["gaveta": ["type": "local", "command": [executable] + args, "enabled": true]],
            ]
        }
        let data = (try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
