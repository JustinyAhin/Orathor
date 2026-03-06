import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            engineSection
            hotkeySection
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedEngine)
    }

    // MARK: - Speech Engine

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Speech Engine")
                .sectionHeaderStyle()

            VStack(alignment: .leading, spacing: 0) {
                engineRow(.apple)
                SubtleDivider()
                engineRow(.deepgram)

                if viewModel.selectedEngine == .deepgram {
                    SubtleDivider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SecureField("Deepgram API Key", text: $viewModel.deepgramApiKey)
                            .textFieldStyle(.roundedBorder)

                        if viewModel.isDeepgramConfigured {
                            Label("API key saved", systemImage: "checkmark.circle.fill")
                                .font(OType.caption)
                                .foregroundStyle(Color.success)
                        } else {
                            Label("Required for cloud transcription", systemImage: "exclamationmark.triangle.fill")
                                .font(OType.caption)
                                .foregroundStyle(Color.warning)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .cardStyle(padding: 0)

            Text(viewModel.selectedEngine.description)
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    private func engineRow(_ engine: SpeechEngine) -> some View {
        Button {
            viewModel.selectedEngine = engine
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.displayName)
                        .font(OType.body)
                        .foregroundStyle(Color.textPrimary)
                    Text(engine == .apple ? "On-device, private" : "Cloud, higher accuracy")
                        .font(OType.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Image(systemName: viewModel.selectedEngine == engine ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        viewModel.selectedEngine == engine ? Color.brand : Color.textTertiary
                    )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hotkeys

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Hotkeys")
                .sectionHeaderStyle()

            VStack(spacing: 0) {
                HotkeyField(label: "Insert at cursor", hotkey: $viewModel.insertHotkey)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)

                SubtleDivider()

                OptionalHotkeyField(label: "Copy to clipboard", hotkey: $viewModel.clipboardHotkey)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
            }
            .cardStyle(padding: 0)

            Text("Available: \(HotkeyModifier.allCases.map(\.displayName).joined(separator: ", "))")
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
        }
    }
}
