import Foundation

public struct RequirementStatus: Identifiable, Equatable, Sendable {
    public let id: String; public let title: String; public let isInstalled: Bool
}

public struct RequirementChecker {
    private let executables: Set<String>
    public init(executables: Set<String>? = nil, existingPaths: Set<String>? = nil) {
        self.executables = executables ?? Self.detectedExecutables(existingPaths: existingPaths)
    }
    public func check() -> [RequirementStatus] { [RequirementStatus(id: "brew", title: "Homebrew", isInstalled: executables.contains("brew")), RequirementStatus(id: "rclone", title: "rclone", isInstalled: executables.contains("rclone")), RequirementStatus(id: "fuse", title: "FUSE-T", isInstalled: executables.contains("fuse-t"))] }
    public static func installationCommand(for statuses: [RequirementStatus]) -> String? {
        let missing = Set(statuses.filter { !$0.isInstalled }.map(\.id)); var commands: [String] = []
        let secureCurl = "/usr/bin/curl --fail --silent --show-error --location --proto '=https' --tlsv1.2"
        if missing.contains("brew") { commands.append("/bin/bash -c \"$(\(secureCurl) https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"") }
        // The official rclone documentation warns that its Homebrew package may
        // omit mount support on macOS, therefore use the signed upstream installer.
        if missing.contains("rclone") { commands.append("\(secureCurl) https://rclone.org/install.sh | sudo /bin/bash") }
        if missing.contains("fuse") { commands.append("HOMEBREW_NO_INSTALL_CLEANUP=1 brew install --cask fuse-t") }
        return commands.isEmpty ? nil : commands.joined(separator: " && ")
    }
    private static func detectedExecutables(existingPaths: Set<String>? = nil) -> Set<String> {
        let paths = [
            "/opt/homebrew/bin/brew", "/usr/local/bin/brew",
            "/opt/homebrew/bin/rclone", "/usr/local/bin/rclone",
            "/Library/Application Support/fuse-t", "/Library/Frameworks/fuse_t.framework",
            "/Applications/fuse-t.app", "/opt/homebrew/Caskroom/fuse-t",
        ]
        var result = Set<String>()
        let existingPaths = existingPaths ?? Set(paths.filter { FileManager.default.fileExists(atPath: $0) })
        for path in existingPaths {
            if path.contains("brew") { result.insert("brew") }
            if path.contains("rclone") { result.insert("rclone") }
            if path.contains("fuse") { result.insert("fuse-t") }
        }
        return result
    }
}

public enum RequirementInstallScript {
    public static func make(command: String) -> String {
        "#!/bin/zsh\nset -euo pipefail\numask 077\ntrap '/bin/rm -f -- \"$0\"' EXIT\n\n\(command)\nprintf '\\nInstallazione completata. Torna a MontaMac e premi Riesegui controllo.\\n'\n"
    }
}
