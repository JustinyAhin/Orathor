import SwiftUI

/// A single permission line — icon tile + title/caption on the left, live
/// status or action on the right. Shared by onboarding and Settings.
struct PermissionRow: View {
    let title: String
    let caption: String
    let symbol: String
    let status: PermissionsService.Status
    let grant: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            TintedIconTile(symbol: symbol, color: .indicatorBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                Text(caption)
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .granted:
            Label("Granted", systemImage: "checkmark.circle.fill")
                .font(OType.caption)
                .foregroundStyle(Color.success)
        case .notDetermined:
            Button("Grant", action: grant)
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .denied:
            HStack(spacing: Spacing.sm) {
                Label("Not granted", systemImage: "exclamationmark.triangle.fill")
                    .font(OType.caption)
                    .foregroundStyle(Color.warning)
                Button("Open Settings", action: openSettings)
                    .font(OType.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brand)
            }
        }
    }
}
