import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            engineSection
            hotkeySection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedEngine)
    }

    // MARK: - Speech Engine

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Speech Engine")
                .sectionHeaderStyle()

            VStack(alignment: .leading, spacing: Spacing.md) {
                Picker("Engine", selection: $viewModel.selectedEngine) {
                    ForEach(SpeechEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if viewModel.selectedEngine == .deepgram {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SecureField("API Key", text: $viewModel.deepgramApiKey)
                            .textFieldStyle(.roundedBorder)

                        if viewModel.isDeepgramConfigured {
                            Label("API key saved", systemImage: "checkmark.circle.fill")
                                .font(OType.caption)
                                .foregroundStyle(Color.success)
                        } else {
                            Label("Required", systemImage: "exclamationmark.triangle.fill")
                                .font(OType.caption)
                                .foregroundStyle(Color.warning)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .cardStyle()

            Text(viewModel.selectedEngine.description)
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
        }
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
