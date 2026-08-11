public enum UtilityDestination: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case transfers
    case cache
    case issues

    public var id: String { rawValue }
    public var titleKey: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .transfers: return "Trasferimenti"
        case .cache: return "Gestione cache"
        case .issues: return "Problemi"
        }
    }
    public var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .transfers: return "arrow.left.arrow.right.circle.fill"
        case .cache: return "internaldrive.fill"
        case .issues: return "exclamationmark.bubble.fill"
        }
    }
}
