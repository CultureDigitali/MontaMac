import Foundation

public protocol MountProcessHandling: AnyObject {
    var isRunning: Bool { get }
    func terminate()
    func observeTermination(_ handler: @escaping @Sendable (Int32) -> Void)
}

extension Process: MountProcessHandling {
    public func observeTermination(_ handler: @escaping @Sendable (Int32) -> Void) {
        terminationHandler = { process in handler(process.terminationStatus) }
    }
}
