import Foundation

/// Small glob matcher: `*` and `?` stay within one path component, `**` crosses components,
/// `{a,b}` is alternation. Case-sensitive. A pattern without `/` matches the file name only.
public struct Glob {
    private let regex: Regex<Substring>
    private let matchesBaseName: Bool

    public init(_ pattern: String) throws {
        matchesBaseName = !pattern.contains("/")
        var source = "^"
        var braceDepth = 0
        let characters = Array(pattern)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            switch character {
            case "*":
                if index + 1 < characters.count, characters[index + 1] == "*" {
                    index += 1
                    if index + 1 < characters.count, characters[index + 1] == "/" {
                        index += 1
                        source += "(?:.*/)?"
                    } else {
                        source += ".*"
                    }
                } else {
                    source += "[^/]*"
                }
            case "?": source += "[^/]"
            case "{": braceDepth += 1; source += "(?:"
            case "}" where braceDepth > 0: braceDepth -= 1; source += ")"
            case "," where braceDepth > 0: source += "|"
            default: source += NSRegularExpression.escapedPattern(for: String(character))
            }
            index += 1
        }
        guard braceDepth == 0 else { throw GavetaError.invalidArgument("glob has an unclosed \"{\": \(pattern)") }
        source += "$"
        do {
            regex = try Regex(source)
        } catch {
            throw GavetaError.invalidArgument("invalid glob: \(pattern)")
        }
    }

    /// `relativePath` is relative to the searched folder, with `/` separators.
    public func matches(_ relativePath: String) -> Bool {
        let subject = matchesBaseName ? String(relativePath.split(separator: "/").last ?? "") : relativePath
        return (try? regex.wholeMatch(in: subject)) != nil
    }
}
