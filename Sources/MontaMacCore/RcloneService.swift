import Foundation

public final class RcloneService: RcloneServicing {
    public let rcloneURL: URL
    public init(rcloneURL: URL? = nil) {
        let candidates = ["/opt/homebrew/bin/rclone", "/usr/local/bin/rclone", "/usr/bin/rclone"]
        self.rcloneURL = rcloneURL ?? candidates.map(URL.init(fileURLWithPath:)).first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) ?? URL(fileURLWithPath: candidates[0])
    }

    public var isAvailable: Bool { FileManager.default.isExecutableFile(atPath: rcloneURL.path) }

    public func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL, cachePolicy: CachePolicy) -> [String] {
        [
            "nfsmount", connection.remoteSpec, connection.mountPath,
            "--config", configURL.path,
            "--cache-dir", cacheDirectory.path,
            "--vfs-cache-mode", "full",
            "--vfs-cache-max-age", "1h",
            "--dir-cache-time", "30s",
            "--buffer-size", "64M",
            "--stats", "5s",
            "--stats-one-line",
            "--stats-log-level", "NOTICE",
            "--umask", "077",
        ] + cachePolicy.rcloneArguments
    }

    @discardableResult public func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> any MountProcessHandling {
        guard isAvailable else { throw RcloneError.notInstalled }
        let process = Process()
        process.executableURL = rcloneURL
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            output(text)
        }
        try process.run()
        return process
    }

    public func obscure(_ password: String) throws -> String {
        guard isAvailable else { throw RcloneError.notInstalled }
        let process = Process()
        process.executableURL = rcloneURL
        process.arguments = ["obscure", "-"]
        let output = Pipe(); let input = Pipe()
        process.standardOutput = output; process.standardInput = input
        try process.run()
        input.fileHandleForWriting.write(Data((password + "\n").utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let value = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { throw RcloneError.obscureFailed }
        return value
    }

    public func unmount(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", url.path]
        try process.run(); process.waitUntilExit()
        if process.terminationStatus != 0 { throw RcloneError.unmountFailed }
    }
}

public enum RcloneError: LocalizedError { case notInstalled, obscureFailed, unmountFailed
    public var errorDescription: String? {
        switch self { case .notInstalled: return "rclone non è installato. Installa rclone e FUSE-T."; case .obscureFailed: return "Impossibile proteggere la configurazione rclone."; case .unmountFailed: return "Impossibile smontare il drive. Chiudi eventuali file aperti e riprova." }
    }
}
