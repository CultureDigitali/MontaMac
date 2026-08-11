import Foundation
import MontaMacCore

@MainActor
final class IssueCenter: ObservableObject {
    @Published private(set) var issues: [AppIssue]
    @Published var banner: AppIssue?
    private let store: IssueStore

    init(store: IssueStore = IssueStore()) {
        self.store = store
        issues = (try? store.recent(limit: 100)) ?? []
    }

    func report(_ issue: AppIssue) {
        do {
            try store.record(issue)
            issues = try store.recent(limit: 100)
        } catch {
            issues.append(issue)
            issues = Array(issues.suffix(100))
        }
        banner = issue
    }

    func dismissBanner() { banner = nil }

    func clear() {
        do {
            try store.clear()
            issues = []
            banner = nil
        } catch {
            report(AppIssue(code: .activityWriteFailed, arguments: [error.localizedDescription], severity: .error))
        }
    }
}
