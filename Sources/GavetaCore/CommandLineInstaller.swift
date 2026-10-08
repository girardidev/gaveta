import Foundation

/// Installs the `gaveta` command by symlinking it into the PATH (default `/usr/local/bin/gaveta`).
public struct CommandLineInstaller: Sendable {
    public enum Outcome: Sendable, Equatable {
        case installed
        case alreadyInstalled
    }

    public static let defaultLinkPath = ClientConfig.installedPath

    public let linkPath: String

    public init(linkPath: String = CommandLineInstaller.defaultLinkPath) {
        self.linkPath = linkPath
    }

    /// Points `linkPath` at `target` (an executable). Idempotent; replaces a stale symlink,
    /// but never a regular file or directory.
    public func install(target: String) throws -> Outcome {
        let canonicalTarget: String
        do {
            canonicalTarget = try PathCanonicalizer.canonicalize(target)
        } catch {
            throw GavetaError.pathDoesNotExist(target)
        }
        guard FileManager.default.isExecutableFile(atPath: canonicalTarget) else {
            throw GavetaError.installFailed("\(canonicalTarget) is not an executable file.")
        }

        let fileManager = FileManager.default
        if let info = try existingEntry() {
            guard info.isSymlink else { throw GavetaError.notASymlink(linkPath) }
            if (try? fileManager.destinationOfSymbolicLink(atPath: linkPath)) == canonicalTarget {
                return .alreadyInstalled
            }
        }

        do {
            let parent = URL(filePath: linkPath).deletingLastPathComponent()
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            if (try existingEntry()) != nil { try fileManager.removeItem(atPath: linkPath) }
            try fileManager.createSymbolicLink(atPath: linkPath, withDestinationPath: canonicalTarget)
        } catch {
            throw map(error, manual: "sudo mkdir -p \"\(parentPath)\" && sudo ln -sf \"\(canonicalTarget)\" \"\(linkPath)\"")
        }
        return .installed
    }

    /// Removes the symlink. Returns false when nothing was installed.
    @discardableResult
    public func uninstall() throws -> Bool {
        guard let info = try existingEntry() else { return false }
        guard info.isSymlink else { throw GavetaError.notASymlink(linkPath) }
        do {
            try FileManager.default.removeItem(atPath: linkPath)
        } catch {
            throw map(error, manual: "sudo rm \"\(linkPath)\"")
        }
        return true
    }

    // MARK: - Helpers

    private var parentPath: String {
        URL(filePath: linkPath).deletingLastPathComponent().path
    }

    private func existingEntry() throws -> (isSymlink: Bool, Void)? {
        var info = Darwin.stat()
        guard lstat(linkPath, &info) == 0 else {
            if errno == ENOENT { return nil }
            throw GavetaError.installFailed(String(cString: strerror(errno)))
        }
        return (info.st_mode & S_IFMT == S_IFLNK, ())
    }

    private func map(_ error: any Error, manual: String) -> GavetaError {
        let code = (error as? CocoaError)?.code
        let posix = (error as NSError).userInfo[NSUnderlyingErrorKey].flatMap { ($0 as? NSError)?.code }
        if code == .fileWriteNoPermission || posix == Int(EACCES) || posix == Int(EPERM) {
            return .needsAdministrator(command: manual)
        }
        return .installFailed(error.localizedDescription)
    }
}
