import Foundation

@MainActor
public protocol MountMonitoring: AnyObject {
    func isMounted(at url: URL) -> Bool
    func waitUntilMounted(at url: URL, timeout: TimeInterval) async -> Bool
}

@MainActor
public final class MountMonitor: MountMonitoring {
    public init() {}

    public func isMounted(at url: URL) -> Bool {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        process.standardOutput = pipe
        do { try process.run(); process.waitUntilExit() } catch { return false }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.split(separator: "\n").contains { $0.contains(" on \(url.path) ") }
    }

    public func waitUntilMounted(at url: URL, timeout: TimeInterval = 12) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isMounted(at: url) { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}
