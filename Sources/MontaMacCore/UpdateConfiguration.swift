import Foundation

public struct UpdateConfiguration: Equatable, Sendable {
    public let feedURL: URL?
    public let publicKey: String?

    public init(feedURLString: String?, publicKey: String?) {
        if let feedURLString,
           let url = URL(string: feedURLString),
           url.scheme?.lowercased() == "https" {
            feedURL = url
        } else {
            feedURL = nil
        }
        let trimmedKey = publicKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publicKey = trimmedKey?.isEmpty == false ? trimmedKey : nil
    }

    public init(infoDictionary: [String: Any]?) {
        self.init(
            feedURLString: infoDictionary?["SUFeedURL"] as? String,
            publicKey: infoDictionary?["SUPublicEDKey"] as? String
        )
    }

    public var isConfigured: Bool { feedURL != nil && publicKey != nil }
    public func canCheckAutomatically(userEnabled: Bool) -> Bool { isConfigured && userEnabled }
}
