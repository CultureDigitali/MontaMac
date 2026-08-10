import Foundation

public enum MountPathPolicy {
    public static let unsafePathMessage = "Scegli una cartella locale sicura dentro il tuo profilo utente."

    public static func validationError(for path: String) -> String? {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let resolved = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        let protectedRoots = ["/", "/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/private"]
        let isProtected = [path, standardized, resolved].contains { candidate in
            protectedRoots.contains { root in
                candidate == root || (root != "/" && candidate.hasPrefix(root + "/"))
            }
        }
        return isProtected ? unsafePathMessage : nil
    }
}
