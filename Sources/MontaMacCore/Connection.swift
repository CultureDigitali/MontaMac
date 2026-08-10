import Foundation

public enum RemoteProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case ftp
    case sftp
    case webdav

    public var id: String { rawValue }
    public var title: String { rawValue.uppercased() }
    var rcloneType: String { self == .webdav ? "webdav" : rawValue }
}

public struct RemoteConnection: Codable, Identifiable, Equatable, Sendable {
    public static let defaultProfileGroup = "Senza cartella"

    public var id: UUID
    public var name: String
    public var protocolType: RemoteProtocol
    public var host: String
    public var port: Int
    public var username: String
    public var remotePath: String
    public var mountPath: String
    public var profileGroup: String
    public var isFavorite: Bool
    public var lastUsedAt: Date?

    public init(id: UUID = UUID(), name: String, protocolType: RemoteProtocol, host: String, port: Int, username: String, remotePath: String, mountPath: String, profileGroup: String = RemoteConnection.defaultProfileGroup, isFavorite: Bool = false, lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.protocolType = protocolType
        self.host = host
        self.port = port
        self.username = username
        self.remotePath = remotePath
        self.mountPath = mountPath
        self.profileGroup = Self.normalizedProfileGroup(profileGroup)
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
    }

    public static func blank(protocolType: RemoteProtocol) -> RemoteConnection {
        RemoteConnection(name: "Nuova connessione", protocolType: protocolType, host: "", port: protocolType == .sftp ? 22 : protocolType == .webdav ? 443 : 21, username: "", remotePath: "/", mountPath: "")
    }

    public mutating func markUsed(at date: Date = .now) { lastUsedAt = date }

    public var validationError: String? {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              URL(fileURLWithPath: mountPath).path == mountPath,
              mountPath.hasPrefix("/") else {
            return "Inserisci un host valido e un percorso locale assoluto."
        }
        guard port > 0 && port < 65_536 else { return "Inserisci una porta valida." }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Inserisci il nome utente." }
        guard [name, host, username, remotePath].allSatisfy({ !$0.contains("\n") && !$0.contains("\r") }) else { return "I campi non possono contenere ritorni a capo." }
        if let error = MountPathPolicy.validationError(for: mountPath) { return error }
        return nil
    }

    public var rcloneRemoteName: String {
        "montamac_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    public var remoteSpec: String { "\(rcloneRemoteName):\(remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)")" }

    enum CodingKeys: String, CodingKey {
        case id, name, protocolType, host, port, username, remotePath, mountPath, profileGroup, isFavorite, lastUsedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        protocolType = try container.decode(RemoteProtocol.self, forKey: .protocolType)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        remotePath = try container.decode(String.self, forKey: .remotePath)
        mountPath = try container.decode(String.self, forKey: .mountPath)
        profileGroup = Self.normalizedProfileGroup(try container.decodeIfPresent(String.self, forKey: .profileGroup) ?? Self.defaultProfileGroup)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(protocolType, forKey: .protocolType)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encode(remotePath, forKey: .remotePath)
        try container.encode(mountPath, forKey: .mountPath)
        try container.encode(Self.normalizedProfileGroup(profileGroup), forKey: .profileGroup)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
    }

    public static func normalizedProfileGroup(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? defaultProfileGroup : value
    }
}
