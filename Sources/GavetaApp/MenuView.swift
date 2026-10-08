import AppKit
import GavetaCore
import SwiftUI

struct MenuView: View {
    let observer: FolderObserver
    let loginItem: LoginItem
    @State private var copiedClient: MCPClient?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear { loginItem.refresh() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Gaveta").font(.headline)
            Spacer()
            let active = observer.folders.filter { !$0.paused }.count
            Text(observer.folders.isEmpty ? "" : "\(active) of \(observer.folders.count) active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let message = observer.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(14)
                .fixedSize(horizontal: false, vertical: true)
        } else if observer.folders.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No folders shared.")
                Text("gaveta add ~/your/folder")
                    .font(.system(.callout, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
                Text("Folders are shared from the terminal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(observer.folders) { folder in
                        FolderRow(folder: folder) { paused in
                            observer.setPaused(folder, paused: paused)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Menu {
                ForEach(MCPClient.allCases, id: \.self) { client in
                    Button(client.displayName) { copyConfig(for: client) }
                }
            } label: {
                Label(
                    copiedClient.map { "\($0.displayName) config copied" } ?? "Copy MCP config",
                    systemImage: copiedClient == nil ? "doc.on.doc" : "checkmark"
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Toggle("Launch at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .toggleStyle(.checkbox)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)

            if let message = loginItem.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
            }

            Button("Quit Gaveta") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func copyConfig(for client: MCPClient) {
        let json = ClientConfig.json(for: client, executable: Self.executablePath())
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        copiedClient = client
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedClient == client { copiedClient = nil }
        }
    }

    /// Installed symlink if present, otherwise the `gaveta` bundled inside the app, otherwise PATH.
    static func executablePath() -> String {
        let bundled = Bundle.main.bundleURL.appending(path: "Contents/Helpers/gaveta").path(percentEncoded: false)
        let fallback = FileManager.default.isExecutableFile(atPath: bundled) ? bundled : "gaveta"
        return ClientConfig.preferredExecutable(fallback: fallback)
    }
}
