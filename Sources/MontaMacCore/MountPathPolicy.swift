import Foundation

public enum MountPathPolicy {
    public static let unsafePathMessage = "Scegli una cartella locale sicura dentro il tuo profilo utente."

    public static func validationError(for path: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath().path
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let normalized = url.path
        let resolved = url.resolvingSymlinksInPath().path
        // A mount must be below the current home directory, including after
        // resolution of symlinks in existing ancestor directories.
        let insideHome = [normalized, resolved].allSatisfy { candidate in
            candidate.hasPrefix(home + "/")
        }
        return insideHome ? nil : unsafePathMessage
    }
}
