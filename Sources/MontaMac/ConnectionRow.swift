import SwiftUI
import MontaMacCore

struct ConnectionRow: View {
    let connection: RemoteConnection; let status: MountStatus
    private var color: Color { switch status { case .mounted: return .green; case .connecting, .disconnecting: return .orange; case .failed: return .red; case .disconnected: return .secondary } }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.fill").foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text(connection.name).fontWeight(.medium)
                Text("\(connection.protocolType.title) · \(connection.profileGroup)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(); Circle().fill(color).frame(width: 8, height: 8)
        }.padding(.vertical, 4)
    }
}
