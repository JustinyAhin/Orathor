import SwiftUI

struct PhononSettingsView: View {
    @Bindable var runtime: PhononRuntime
    let canManage: Bool
    let install: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !PhononRuntime.isSupported {
                Label("Phonon 2 requires an Apple silicon Mac", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.warning)
            } else if runtime.isInstalling {
                HStack(spacing: Spacing.sm) {
                    ProgressView().controlSize(.small)
                    Text(runtime.installationMessage)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button("Cancel") { runtime.cancelInstallation() }
                }
            } else {
                HStack {
                    Label(
                        runtime.isInstalled ? "Installed · English only" : "Download required",
                        systemImage: runtime.isInstalled ? "checkmark.circle" : "arrow.down.circle"
                    )
                    .foregroundStyle(runtime.isInstalled ? Color.success : Color.textSecondary)
                    Spacer()
                    Button(runtime.isInstalled ? "Download again" : "Download engine", action: install)
                        .disabled(!canManage)
                }
            }
            Text(
                "The model is 164 MB. Allow about 3 GB of disk space for setup and 3 GB of memory while loaded. After setup, dictation works offline."
            )
            .font(OType.caption)
            .foregroundStyle(Color.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            if let modelURL = URL(string: "https://www.fermionresearch.com/models/phonon-2/") {
                Link("Phonon 2 by Fermion Research · CC BY 4.0", destination: modelURL)
                    .font(OType.caption)
            }
        }
        .padding(Spacing.lg)
        .cardStyle(padding: 0)
        .alert(
            "Couldn’t Set Up Phonon",
            isPresented: Binding(
                get: { runtime.errorMessage != nil },
                set: { if !$0 { runtime.clearError() } }
            )
        ) {
            Button("OK") { runtime.clearError() }
        } message: {
            Text(runtime.errorMessage ?? "Please retry the download.")
        }
    }
}
