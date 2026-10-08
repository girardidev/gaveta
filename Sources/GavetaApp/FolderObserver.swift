import Foundation
import GavetaCore
import Observation

/// Keeps the folder list in sync with `folders.json`. The app only reads the file and
/// toggles `paused`; adding and removing folders is done from the terminal.
@MainActor
@Observable
final class FolderObserver {
    private(set) var folders: [Folder] = []
    private(set) var errorMessage: String?

    @ObservationIgnored private let store: FolderStore
    @ObservationIgnored private var source: DispatchSourceFileSystemObject?
    @ObservationIgnored private var pendingReload: Task<Void, Never>?

    init(store: FolderStore = FolderStore()) {
        self.store = store
        reload()
        startWatching()
    }

    func reload() {
        do {
            folders = try store.load().folders
            errorMessage = nil
        } catch {
            folders = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setPaused(_ folder: Folder, paused: Bool) {
        do {
            try FolderManager(store: store).setPaused(folder.alias, paused: paused)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        reload()
    }

    // MARK: - Watching

    /// Watches the containing directory: atomic writes replace the file, so only the
    /// directory sees the change.
    private func startWatching() {
        source?.cancel()
        source = nil

        let directory = store.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .link, .extend, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.directoryChanged() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    private func directoryChanged() {
        // Coalesce bursts (temporary file + rename) into a single reload.
        pendingReload?.cancel()
        pendingReload = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            self?.reload()
            // The directory itself may have been replaced; re-arm the watcher.
            if let self, !FileManager.default.fileExists(atPath: self.store.fileURL.deletingLastPathComponent().path) {
                self.startWatching()
            }
        }
    }
}
