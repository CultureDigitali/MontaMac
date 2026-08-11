import Foundation

public protocol RcloneServicing: AnyObject {
    var isAvailable: Bool { get }
    func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL) -> [String]
    func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> any MountProcessHandling
    func obscure(_ password: String) throws -> String
    func unmount(at url: URL) throws
}
