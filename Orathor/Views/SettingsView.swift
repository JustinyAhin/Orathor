import Sparkle
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let updater: SPUUpdater
    @State private var copiedDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("Settings")
                .font(OType.largeTitle)
                .foregroundStyle(Color.textPrimary)
            engineSection
            hotkeySection
            soundsSection
            appearanceSection
            updatesSection
            diagnosticsSection
            versionFooter
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedEngine)
    }

    // MARK: - Version

    private var versionFooter: some View {
        HStack {
            Spacer()
            Text("Orathor \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
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
                SubtleDivider()
                engineRow(.openAIWhisper)

                if viewModel.selectedEngine == .deepgram || viewModel.selectedEngine == .openAIWhisper {
                    SubtleDivider()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if viewModel.selectedEngine == .deepgram {
                            SecureField("Deepgram API Key", text: $viewModel.deepgramApiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("OpenAI API Key", text: $viewModel.openAIApiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        if selectedCloudEngineIsConfigured {
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

                    SubtleDivider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Language")
                                .font(OType.body)
                                .foregroundStyle(Color.textPrimary)
                            Text("Single language is more accurate than auto-detect")
                                .font(OType.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Picker("", selection: $viewModel.transcriptionLanguage) {
                            ForEach(DeepgramLanguage.allOptions, id: \.code) { lang in
                                Text(lang.label).tag(lang.code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
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
                    Text(engineSubtitle(engine))
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

    private var selectedCloudEngineIsConfigured: Bool {
        switch viewModel.selectedEngine {
        case .apple:
            true
        case .deepgram:
            viewModel.isDeepgramConfigured
        case .openAIWhisper:
            viewModel.isOpenAIConfigured
        }
    }

    private func engineSubtitle(_ engine: SpeechEngine) -> String {
        switch engine {
        case .apple:
            "On-device, private"
        case .deepgram:
            "Cloud, higher accuracy"
        case .openAIWhisper:
            "Cloud, low-latency streaming"
        }
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

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Appearance")
                .sectionHeaderStyle()

            VStack(spacing: 0) {
                HStack {
                    Text("Theme")
                        .font(OType.body)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    HStack(spacing: Spacing.xxxs) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    viewModel.appearanceMode = mode
                                }
                            } label: {
                                Text(mode.displayName)
                                    .font(OType.captionMedium)
                                    .foregroundStyle(
                                        viewModel.appearanceMode == mode
                                            ? Color.textPrimary
                                            : Color.textTertiary
                                    )
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        viewModel.appearanceMode == mode
                                            ? Color.surfaceSecondary
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: Radius.sm)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Spacing.xxxs)
                    .background(Color.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

                SubtleDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show in Dock")
                            .font(OType.body)
                            .foregroundStyle(Color.textPrimary)
                        Text("Also shows the menu bar when the window is open")
                            .font(OType.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.showInDock)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .cardStyle(padding: 0)
        }
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

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Diagnostics")
                .sectionHeaderStyle()

            VStack(spacing: 0) {
                Button {
                    DiagnosticLogger.shared.copyToPasteboard()
                    copiedDiagnostics = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedDiagnostics = false
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy Diagnostic Log")
                                .font(OType.body)
                                .foregroundStyle(Color.textPrimary)
                            Text(copiedDiagnostics ? "Copied to clipboard!" : "Share with the developer to help debug issues")
                                .font(OType.caption)
                                .foregroundStyle(copiedDiagnostics ? Color.success : Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: copiedDiagnostics ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundStyle(copiedDiagnostics ? Color.success : Color.textTertiary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SubtleDivider()

                Button {
                    NSWorkspace.shared.selectFile(
                        DiagnosticLogger.shared.logFileURL().path,
                        inFileViewerRootedAtPath: DiagnosticLogger.shared.logFileURL().deletingLastPathComponent().path
                    )
                } label: {
                    HStack {
                        Text("Reveal Log File in Finder")
                            .font(OType.body)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "folder")
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
