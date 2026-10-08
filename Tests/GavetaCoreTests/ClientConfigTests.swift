import Foundation
import Testing
@testable import GavetaCore

@Suite("ClientConfig")
struct ClientConfigTests {
    private func parse(_ client: MCPClient, executable: String = "/usr/local/bin/gaveta") throws -> [String: Any] {
        let json = ClientConfig.json(for: client, executable: executable)
        return try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test(arguments: [MCPClient.claudeDesktop, .cursor])
    func standardMcpServersShape(client: MCPClient) throws {
        let server = try #require(((try parse(client))["mcpServers"] as? [String: Any])?["gaveta"] as? [String: Any])
        #expect(server["command"] as? String == "/usr/local/bin/gaveta")
        #expect(server["args"] as? [String] == ["mcp"])
    }

    @Test func claudeCodeDeclaresStdio() throws {
        let server = try #require(((try parse(.claudeCode))["mcpServers"] as? [String: Any])?["gaveta"] as? [String: Any])
        #expect(server["type"] as? String == "stdio")
    }

    @Test func opencodeUsesLocalCommandArray() throws {
        let server = try #require(((try parse(.opencode))["mcp"] as? [String: Any])?["gaveta"] as? [String: Any])
        #expect(server["type"] as? String == "local")
        #expect(server["command"] as? [String] == ["/usr/local/bin/gaveta", "mcp"])
        #expect(server["enabled"] as? Bool == true)
    }

    @Test func escapesPathsWithSpacesAndQuotes() throws {
        let path = "/Applications/Gav eta \"x\".app/Contents/Helpers/gaveta"
        let server = try #require(((try parse(.claudeDesktop, executable: path))["mcpServers"] as? [String: Any])?["gaveta"] as? [String: Any])
        #expect(server["command"] as? String == path)
    }

    @Test func clientNamesRoundTrip() {
        #expect(MCPClient(rawValue: "claude-desktop") == .claudeDesktop)
        #expect(MCPClient.allCases.map(\.rawValue) == ["claude-desktop", "claude-code", "cursor", "opencode"])
    }
}
