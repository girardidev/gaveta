import AppKit
import GavetaCore
import SwiftUI

struct FolderRow: View {
    let folder: Folder
    let onSetPaused: (Bool) -> Void
    @State private var hovering = false

    private var exists: Bool { FileManager.default.fileExists(atPath: folder.path) }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openInFinder) {
                HStack(spacing: 10) {
                    Image(systemName: exists ? "folder.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(exists ? Color.accentColor : .orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(folder.alias).fontWeight(.medium)
                            badge
                        }
                        Text(exists ? PathDisplay.abbreviate(folder.path) : "Folder not found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!exists)
            .help(exists ? "Open in Finder" : "The folder no longer exists on disk")

            Toggle("", isOn: Binding(get: { !folder.paused }, set: { onSetPaused(!$0) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(folder.paused ? "Resume agent access" : "Pause agent access")
        }
        .opacity(folder.paused ? 0.55 : 1)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(hovering ? Color.primary.opacity(0.06) : .clear)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
    }

    private var badge: some View {
        let (text, color): (String, Color) = if folder.paused {
            ("paused", .secondary)
        } else if folder.mode == .readwrite {
            ("read/write", .orange)
        } else {
            ("read", .green)
        }
        return Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func openInFinder() {
        NSWorkspace.shared.open(URL(filePath: folder.path))
    }
}
