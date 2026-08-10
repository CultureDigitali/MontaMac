import XCTest
@testable import MontaMacCore

final class ProfileFilterTests: XCTestCase {
    private let profiles = [
        RemoteConnection(name: "Server precedente", protocolType: .sftp, host: "server-old.example", port: 22, username: "anna", remotePath: "/", mountPath: "/Users/anna/old", profileGroup: "Clienti", isFavorite: true, lastUsedAt: Date(timeIntervalSinceReferenceDate: 5)),
        RemoteConnection(name: "Server recente", protocolType: .sftp, host: "server-new.example", port: 22, username: "anna", remotePath: "/", mountPath: "/Users/anna/new", profileGroup: "Personale", isFavorite: true, lastUsedAt: Date(timeIntervalSinceReferenceDate: 10)),
        RemoteConnection(name: "Online", protocolType: .webdav, host: "cloud.example", port: 443, username: "anna", remotePath: "/", mountPath: "/Users/anna/cloud"),
    ]

    func testFavoritesSearchAndRecentOrdering() {
        let result = ProfileFilter.profiles(profiles, scope: .favorites, query: "server", statusFor: { _ in .disconnected })

        XCTAssertEqual(result.map(\.name), ["Server recente", "Server precedente"])
    }

    func testMountedScopeKeepsOnlyMountedProfiles() {
        let result = ProfileFilter.profiles(profiles, scope: .mounted, query: "", statusFor: { $0.name == "Online" ? .mounted : .disconnected })

        XCTAssertEqual(result.map(\.name), ["Online"])
    }

    func testGroupsExcludeDefaultGroupAndAreSorted() {
        XCTAssertEqual(ProfileFilter.groups(in: profiles), ["Clienti", "Personale"])
    }
}
