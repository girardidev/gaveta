import Foundation
import GavetaCore
import MCP

public enum GavetaServer {
    public static let version = "0.1.0"

    /// Serves MCP over stdio until the client disconnects. stdout carries only protocol messages.
    public static func runStdio(handler: ToolHandler = ToolHandler()) async throws {
        let server = Server(
            name: "gaveta",
            version: version,
            instructions: "Gaveta gives access to folders the user explicitly shared. Call list_folders first.",
            capabilities: .init(tools: .init(listChanged: true))
        )

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: handler.availableTools())
        }
        await server.withMethodHandler(CallTool.self) { params in
            handler.call(name: params.name, arguments: params.arguments)
        }

        try await server.start(transport: StdioTransport())

        // Tell the client when write_file appears or disappears (a readwrite folder was added,
        // removed or paused), without waiting for a reconnect.
        let watcher = Task {
            var lastState = handler.isWriteEnabled()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let state = handler.isWriteEnabled()
                if state != lastState {
                    lastState = state
                    try? await server.notify(ToolListChangedNotification.message())
                }
            }
        }

        await server.waitUntilCompleted()
        watcher.cancel()
    }
}
