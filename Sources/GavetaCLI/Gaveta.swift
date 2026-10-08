import ArgumentParser
import Foundation
import GavetaCore

@main
struct Gaveta: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gaveta",
        abstract: "Share specific folders with AI agents through MCP.",
        subcommands: [Add.self, Remove.self, List.self, Pause.self, Resume.self, Mcp.self, Config.self, Install.self, Uninstall.self]
    )
}

/// Prints a Portuguese error to stderr and exits with a non-zero status.
func fail(_ error: any Error) -> ExitCode {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data("gaveta: error: \(message)\n".utf8))
    return .failure
}

func abbreviate(_ path: String) -> String { PathDisplay.abbreviate(path) }
