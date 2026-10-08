import Foundation

public enum PathDisplay {
    /// `/Users/me/Projetos/site` → `~/Projetos/site`. Paths outside the home are returned as is.
    public static func abbreviate(
        _ path: String,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        // `URL.path(percentEncoded:)` keeps the trailing slash of directory URLs; `.path` does not.
        let homePath = home.path
        if path == homePath { return "~" }
        return path.hasPrefix(homePath + "/") ? "~" + path.dropFirst(homePath.count) : path
    }
}
