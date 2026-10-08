import Foundation

public struct SearchMatch: Codable, Sendable, Equatable {
    public let path: String
    /// 1-based line number; `nil` when the match is on the file name.
    public let line: Int?
    public let text: String?
}

public struct SearchResult: Codable, Sendable, Equatable {
    public let query: String
    public let matches: [SearchMatch]
    /// True when the 200-result limit was hit.
    public let truncated: Bool
    /// True when the scan stopped early (too many files); results may be missing.
    public let incomplete: Bool
    public let filesScanned: Int
}

extension FileTools {
    public static let maxSearchResults = 200
    public static let maxSearchFiles = 50_000
    public static let maxSearchFileBytes = 10 * 1_048_576
    static let ignoredDirectories: Set<String> = [".git", "node_modules"]
    static let ignoredFiles: Set<String> = [".DS_Store"]
    static let maxMatchTextLength = 300

    /// Literal text search (case-insensitive unless asked otherwise) over file names and contents.
    /// Skips `.git`, `node_modules`, `.DS_Store`, symlinks, binaries and files over 10 MB.
    public func search(
        query: String, folder: String? = nil, glob: String? = nil, caseSensitive: Bool = false
    ) throws -> SearchResult {
        guard !query.isEmpty else { throw GavetaError.invalidArgument("query must not be empty.") }
        let matcher = try glob.map(Glob.init)

        var roots: [(display: String, path: String)] = []
        if let folder {
            let canonical = try policy.resolveAllowed(folder).path(percentEncoded: false)
            guard try Self.isDirectory(canonical) else {
                throw GavetaError.notADirectory(policy.displayPath(for: canonical))
            }
            roots = [(policy.displayPath(for: canonical), canonical)]
        } else {
            roots = searchableRoots()
            if roots.isEmpty { throw GavetaError.outsideAllowedFolders }
        }

        var state = SearchState(query: query, glob: matcher, caseSensitive: caseSensitive)
        for root in roots where !state.finished {
            scan(directory: root.path, display: root.display, relative: "", state: &state)
        }
        return SearchResult(
            query: query, matches: state.matches, truncated: state.limitReached,
            incomplete: state.scanLimitReached, filesScanned: state.filesScanned
        )
    }

    // MARK: - Internals

    private struct SearchState {
        let query: String
        let glob: Glob?
        let caseSensitive: Bool
        var matches: [SearchMatch] = []
        var filesScanned = 0
        var limitReached = false
        var scanLimitReached = false
        var finished: Bool { limitReached || scanLimitReached }

        init(query: String, glob: Glob?, caseSensitive: Bool) {
            self.query = query
            self.glob = glob
            self.caseSensitive = caseSensitive
        }

        mutating func add(_ match: SearchMatch) {
            if matches.count >= FileTools.maxSearchResults { limitReached = true; return }
            matches.append(match)
            if matches.count >= FileTools.maxSearchResults { limitReached = true }
        }
    }

    /// Active folders, canonical, dropping those nested inside another (they would be searched twice).
    private func searchableRoots() -> [(display: String, path: String)] {
        let resolved: [(alias: String, path: String)] = policy.activeFolders.compactMap { folder in
            (try? PathCanonicalizer.canonicalize(folder.path)).map { (folder.alias, $0) }
        }
        let components = resolved.map { PathCanonicalizer.comparableComponents($0.path) }
        return resolved.enumerated().compactMap { index, root in
            let mine = components[index]
            guard !mine.isEmpty else { return nil }
            let nested = components.enumerated().contains { other, theirs in
                other != index && theirs.count < mine.count && Array(mine[..<theirs.count]) == theirs
            }
            let duplicate = components.enumerated().contains { other, theirs in other < index && theirs == mine }
            return nested || duplicate ? nil : (root.alias, root.path)
        }
    }

    private func scan(directory: String, display: String, relative: String, state: inout SearchState) {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory).sorted() else { return }
        for name in names {
            if state.finished { return }
            let path = directory + "/" + name
            var info = Darwin.stat()
            guard lstat(path, &info) == 0 else { continue }
            let childRelative = relative.isEmpty ? name : relative + "/" + name
            let childDisplay = display + "/" + name

            switch info.st_mode & S_IFMT {
            case S_IFDIR:
                if !Self.ignoredDirectories.contains(name) {
                    scan(directory: path, display: childDisplay, relative: childRelative, state: &state)
                }
            case S_IFREG:
                guard !Self.ignoredFiles.contains(name) else { continue }
                if let glob = state.glob, !glob.matches(childRelative) { continue }
                if state.filesScanned >= Self.maxSearchFiles { state.scanLimitReached = true; return }
                state.filesScanned += 1
                search(file: path, size: Int64(info.st_size), name: name, display: childDisplay, state: &state)
            default:
                continue // symlinks and special files are never followed
            }
        }
    }

    private func search(file path: String, size: Int64, name: String, display: String, state: inout SearchState) {
        let options: String.CompareOptions = state.caseSensitive ? [] : [.caseInsensitive]

        if name.range(of: state.query, options: options) != nil {
            state.add(SearchMatch(path: display, line: nil, text: nil))
            if state.finished { return }
        }
        guard size > 0, size <= Self.maxSearchFileBytes,
              let data = try? Data(contentsOf: URL(filePath: path), options: .mappedIfSafe),
              !data.prefix(8_192).contains(0),
              let text = String(data: data, encoding: .utf8) else { return }

        var lineNumber = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNumber += 1
            guard line.range(of: state.query, options: options) != nil else { continue }
            state.add(SearchMatch(path: display, line: lineNumber, text: String(line.prefix(Self.maxMatchTextLength))))
            if state.finished { return }
        }
    }

    private static func isDirectory(_ path: String) throws -> Bool {
        var info = Darwin.stat()
        guard lstat(path, &info) == 0 else { throw GavetaError.notFound }
        return info.st_mode & S_IFMT == S_IFDIR
    }
}
