import ArgumentParser
import GavetaMCP
import Foundation
import GavetaCore

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Share a folder with agents.")

    @Argument(help: "Folder path.") var path: String
    @Option(name: .shortAndLong, help: "Short alias agents use to refer to the folder (default: folder name).") var alias: String?
    @Flag(help: "Also allow writing (default: read-only).") var write = false

    func run() throws {
        do {
            let result = try FolderManager().add(path: path, alias: alias, mode: write ? .readwrite : .read)
            for warning in result.warnings {
                FileHandle.standardError.write(Data("gaveta: warning: \(warning)\n".utf8))
            }
            let folder = result.folder
            let mode = folder.mode == .readwrite ? "read/write" : "read"
            print("Folder shared: \(folder.alias) → \(abbreviate(folder.path)) (\(mode))")
        } catch {
            throw fail(error)
        }
    }
}

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a shared folder.")

    @Argument(help: "Alias or path of the folder.") var target: String

    func run() throws {
        do {
            let folder = try FolderManager().remove(target)
            print("Folder removed: \(folder.alias) (\(abbreviate(folder.path)))")
        } catch {
            throw fail(error)
        }
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List the shared folders.")

    @Flag(help: "Print as JSON.") var json = false

    func run() throws {
        do {
            let folders = try FolderManager().list()
            if json {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                print(String(decoding: try encoder.encode(folders), as: UTF8.self))
                return
            }
            guard !folders.isEmpty else {
                print("No folders shared. Use: gaveta add ~/your/folder")
                return
            }
            let width = max(folders.map(\.alias.count).max() ?? 0, 6)
            for folder in folders {
                let mode = folder.mode == .readwrite ? "read/write" : "read"
                let state = folder.paused ? " [paused]" : ""
                let alias = folder.alias.padding(toLength: width, withPad: " ", startingAt: 0)
                print("\(alias)  \(abbreviate(folder.path))  (\(mode))\(state)")
            }
        } catch {
            throw fail(error)
        }
    }
}

struct Pause: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Pause a folder: agents lose access immediately.")

    @Argument(help: "Alias of the folder.") var alias: String

    func run() throws {
        do {
            let folder = try FolderManager().setPaused(alias, paused: true)
            print("Folder paused: \(folder.alias)")
        } catch {
            throw fail(error)
        }
    }
}

struct Resume: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Resume a paused folder.")

    @Argument(help: "Alias of the folder.") var alias: String

    func run() throws {
        do {
            let folder = try FolderManager().setPaused(alias, paused: false)
            print("Folder resumed: \(folder.alias)")
        } catch {
            throw fail(error)
        }
    }
}

struct Mcp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start the MCP server over stdio (used by agents, not meant for the terminal).",
        discussion: "Nothing but protocol messages is written to stdout. The log is at ~/Library/Logs/Gaveta/mcp.log."
    )

    func run() async throws {
        do {
            try await GavetaServer.runStdio()
        } catch {
            throw fail(error)
        }
    }
}

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the Gaveta JSON configuration for an MCP client.",
        discussion: "Clients: \(MCPClient.allCases.map(\.rawValue).joined(separator: ", ")). "
            + "The JSON goes to stdout; the hint on where to paste it goes to stderr."
    )

    @Argument(help: "Client: claude-desktop, claude-code, cursor or opencode.") var client: String

    func run() throws {
        guard let mcpClient = MCPClient(rawValue: client.lowercased()) else {
            let valid = MCPClient.allCases.map(\.rawValue).joined(separator: ", ")
            throw fail(ValidationFailure("unknown client \"\(client)\". Use one of: \(valid)."))
        }
        let executable = ClientConfig.preferredExecutable(fallback: Bundle.main.executablePath ?? "gaveta")
        print(ClientConfig.json(for: mcpClient, executable: executable))

        var hint = "Paste into: \(mcpClient.configHint)"
        if mcpClient == .claudeCode {
            hint += "\nOr from the terminal: claude mcp add gaveta -- \"\(executable)\" mcp"
        }
        FileHandle.standardError.write(Data((hint + "\n").utf8))
    }
}

private struct ValidationFailure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
