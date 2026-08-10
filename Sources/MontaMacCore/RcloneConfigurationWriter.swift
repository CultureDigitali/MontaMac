import Foundation

public final class RcloneConfigurationWriter {
    private let rclone: any RcloneServicing
    public init(rclone: any RcloneServicing) { self.rclone = rclone }

    public func write(connection: RemoteConnection, password: String, to url: URL) throws -> URL {
        let protectedPassword = try rclone.obscure(password)
        try SecureFileStore.write(Data(Self.render(connection: connection, obscuredPassword: protectedPassword).utf8), to: url)
        return url
    }

    public static func render(connection: RemoteConnection, obscuredPassword: String) -> String {
        var lines = ["[\(connection.rcloneRemoteName)]", "type = \(connection.protocolType.rcloneType)"]
        if connection.protocolType == .webdav {
            lines += ["url = https://\(connection.host):\(connection.port)", "vendor = other"]
        } else {
            lines += ["host = \(connection.host)", "port = \(connection.port)"]
        }
        lines += ["user = \(connection.username)", "pass = \(obscuredPassword)"]
        return lines.joined(separator: "\n").appending("\n")
    }
}
