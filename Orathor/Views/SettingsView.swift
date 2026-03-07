import Sparkle
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let updater: SPUUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            engineSection
            hotkeySection
            soundsSection
            updatesSection
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

    // MARK: - Sounds

    private var soundsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Sounds")
                .sectionHeaderStyle()

            VStack(spacing: 0) {
                soundRow(label: "Start recording", selection: $viewModel.startSound)
                SubtleDivider()
                soundRow(label: "Stop recording", selection: $viewModel.stopSound)
                SubtleDivider()
                soundRow(label: "Cancel recording", selection: $viewModel.cancelSound)
            }
            .cardStyle(padding: 0)

            HStack {
                Text("Sounds from /System/Library/Sounds")
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                if viewModel.startSound != SoundService.defaultStart
                    || viewModel.stopSound != SoundService.defaultStop
                    || viewModel.cancelSound != SoundService.defaultCancel
                {
                    Button("Reset to defaults") {
                        viewModel.startSound = SoundService.defaultStart
                        viewModel.stopSound = SoundService.defaultStop
                        viewModel.cancelSound = SoundService.defaultCancel
                    }
                    .font(OType.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brand)
                }
            }
        }
    }

    private func soundRow(label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(OType.body)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button {
                SoundService.preview(selection.wrappedValue)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Preview sound")

            Picker("", selection: selection) {
                ForEach(SoundService.availableSounds, id: \.self) { sound in
                    Text(sound).tag(sound)
                }
            }
            .labelsHidden()
            .frame(width: 120)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Updates

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Updates")
                .sectionHeaderStyle()

            VStack(spacing: 0) {
                HStack {
                    Text("Check for updates automatically")
                        .font(OType.body)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

                SubtleDivider()

                Button {
                    updater.checkForUpdates()
                } label: {
                    HStack {
                        Text("Check for Updates Now")
                            .font(OType.body)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .cardStyle(padding: 0)
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

            HStack {
                Text("Available: \(HotkeyModifier.allCases.map(\.displayName).joined(separator: ", "))")
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                if viewModel.insertHotkey != .rightOption
                    || viewModel.clipboardHotkey != nil
                {
                    Button("Reset to defaults") {
                        viewModel.insertHotkey = .rightOption
                        viewModel.clipboardHotkey = nil
                    }
                    .font(OType.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brand)
                }
            }
        }
    }
}
