import Foundation
import Security

public protocol CredentialStoring {
    func password(for id: UUID) throws -> String?
    func save(password: String, for id: UUID) throws
    func deletePassword(for id: UUID) throws
}

public final class CredentialStore: CredentialStoring {
    private let service = "MontaMac"
    public init() {}

    public func password(for id: UUID) throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString, kSecReturnData as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CredentialError.keychain(status) }
        return String(data: data, encoding: .utf8)
    }

    public func save(password: String, for id: UUID) throws {
        try deletePassword(for: id)
        let query = Self.makeAddQuery(password: password, id: id, service: service)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialError.keychain(status) }
    }

    static func makeAddQuery(password: String, id: UUID, service: String = "MontaMac") -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: Data(password.utf8),
        ]
    }

    public func deletePassword(for id: UUID) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.keychain(status) }
    }
}

public enum CredentialError: LocalizedError { case keychain(OSStatus)
    public var errorDescription: String? { "Impossibile accedere al Portachiavi." }
}
