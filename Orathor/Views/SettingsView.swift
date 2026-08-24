import OrathorLicensing
import Sparkle
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var dictionaryService: PersonalDictionaryService
    var permissions: PermissionsService
    @Bindable var launchAtLogin: LaunchAtLoginService
    var license: LicenseManager
    let updater: SPUUpdater
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @State private var copiedDiagnostics = false
    @State private var formattingAvailable = true
    @State private var formattingMessage: String?
    @State private var didPromptAccessibility = false
    @State private var licenseKeyInput = ""
    @State private var licenseActionError: String?
    @State private var isActivatingLicense = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("Settings")
                .font(OType.largeTitle)
                .foregroundStyle(Color.textPrimary)
            engineSection
            permissionsSection
            formattingSection
            PersonalDictionarySettingsView(
                dictionary: dictionaryService,
                settings: viewModel
            )
            hotkeySection
            soundsSection
            generalSection
            appearanceSection
            updatesSection
            if license.isGated {
                licenseSection
            }
            diagnosticsSection
            versionFooter
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedEngine)
        .onAppear(perform: refreshFormattingStatus)
        .task {
            launchAtLogin.refresh()
            await permissions.pollWhileVisible()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                launchAtLogin.refresh()
            }
        }
        .alert("Couldn’t Update Launch at Login", isPresented: launchAtLoginErrorIsPresented) {
            Button("OK") { launchAtLogin.clearError() }
        } message: {
            Text(launchAtLogin.errorMessage ?? "An unknown error occurred.")
        }
    }

    private func refreshFormattingStatus() {
        let status = TranscriptPolisher.status
        formattingAvailable = status.available
        formattingMessage = status.message
    }

    private var launchAtLoginErrorIsPresented: Binding<Bool> {
        Binding(
            get: { launchAtLogin.errorMessage != nil },
            set: { if !$0 { launchAtLogin.clearError() } }
        )
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
            ContentSectionHeader(title: "Speech engine", symbol: "waveform")

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

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "Permissions", symbol: "lock.shield")

            VStack(spacing: 0) {
                PermissionRow(
                    title: "Microphone",
                    caption: "Hears your voice while you dictate",
                    symbol: "mic.fill",
                    status: permissions.microphone,
                    grant: { Task { await permissions.requestMicrophone() } },
                    openSettings: PermissionsService.openMicrophoneSettings
                )
                SubtleDivider()
                PermissionRow(
                    title: "Speech recognition",
                    caption: "Turns your speech into text on-device",
                    symbol: "waveform",
                    status: permissions.speechRecognition,
                    grant: { Task { await permissions.requestSpeechRecognition() } },
                    openSettings: PermissionsService.openSpeechSettings
                )
                SubtleDivider()
                PermissionRow(
                    title: "Accessibility",
                    caption: "Lets Orathor insert text at your cursor",
                    symbol: "accessibility",
                    status: accessibilityStatus,
                    grant: {
                        permissions.promptAccessibility()
                        didPromptAccessibility = true
                    },
                    openSettings: PermissionsService.openAccessibilitySettings
                )
                SubtleDivider()
                Button {
                    openWindow(id: "onboarding")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Text("Show welcome guide")
                            .font(OType.body)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "questionmark.circle")
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

    private var accessibilityStatus: PermissionsService.Status {
        if permissions.accessibility { return .granted }
        return didPromptAccessibility ? .denied : .notDetermined
    }

    private var formattingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "Formatting", symbol: "wand.and.stars")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart formatting")
                        .font(OType.body)
                        .foregroundStyle(formattingAvailable ? Color.textPrimary : Color.textTertiary)
                    Text(formattingMessage ?? "On-device cleanup — fixes punctuation and removes filler words")
                        .font(OType.caption)
                        .foregroundStyle(formattingAvailable ? Color.textTertiary : Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $viewModel.smartFormattingEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!formattingAvailable)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .cardStyle(padding: 0)
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
            ContentSectionHeader(title: "Sounds", symbol: "speaker.wave.2.fill")

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

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "General", symbol: "gearshape.fill")

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(OType.body)
                            .foregroundStyle(
                                launchAtLogin.isAvailable ? Color.textPrimary : Color.textTertiary
                            )
                        Text(launchAtLoginCaption)
                            .font(OType.caption)
                            .foregroundStyle(
                                launchAtLogin.status == .requiresApproval
                                    ? Color.warning
                                    : Color.textTertiary
                            )
                    }
                    Spacer()
                    if launchAtLogin.status == .requiresApproval {
                        Button("Open Settings") {
                            launchAtLogin.openSystemSettings()
                        }
                        .font(OType.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.brand)
                    }
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin.isRegistered },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!launchAtLogin.isAvailable)
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

    private var launchAtLoginCaption: String {
        switch launchAtLogin.status {
        case .disabled, .enabled:
            "Start Orathor automatically when you sign in"
        case .requiresApproval:
            "Approval required in System Settings"
        case .unavailable:
            "Launch at login is unavailable"
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "Appearance", symbol: "paintbrush.fill")

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

            }
            .cardStyle(padding: 0)
        }
    }

    // MARK: - Updates

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "Updates", symbol: "arrow.triangle.2.circlepath")

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
            ContentSectionHeader(title: "Diagnostics", symbol: "stethoscope")

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

    // MARK: - License

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "License", symbol: "key.fill")

            VStack(alignment: .leading, spacing: 0) {
                licenseStatusRow

                if case .licensed = license.state {
                    SubtleDivider()
                    Button {
                        Task {
                            licenseActionError = nil
                            do {
                                try await license.deactivate()
                            } catch {
                                licenseActionError = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            Text("Deactivate on this Mac")
                                .font(OType.body)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    SubtleDivider()
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            TextField("License key", text: $licenseKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isActivatingLicense)
                            Button(isActivatingLicense ? "Activating…" : "Activate") {
                                Task { await activateLicense() }
                            }
                            .disabled(isActivatingLicense || licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        if let licenseActionError {
                            Label(licenseActionError, systemImage: "exclamationmark.triangle.fill")
                                .font(OType.caption)
                                .foregroundStyle(Color.warning)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private var licenseStatusRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(licenseStatusTitle)
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                Text(licenseStatusCaption)
                    .font(OType.caption)
                    .foregroundStyle(licenseStatusCaptionColor)
            }
            Spacer()
            Image(systemName: licenseStatusSymbol)
                .font(.system(size: 16))
                .foregroundStyle(licenseStatusCaptionColor)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var licenseStatusTitle: String {
        switch license.state {
        case .licensed: "Licensed"
        case .trialing: "Free trial"
        case .trialExpired: "Trial ended"
        case .licenseInvalid: "License problem"
        }
    }

    private var licenseStatusCaption: String {
        switch license.state {
        case .licensed(let email):
            if let key = license.maskedLicenseKey {
                email.map { "\(key) — \($0)" } ?? key
            } else {
                "This Mac is activated"
            }
        case .trialing(let daysLeft):
            daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
        case .trialExpired:
            "Enter a license key to keep dictating"
        case .licenseInvalid(let reason):
            reason
        }
    }

    private var licenseStatusCaptionColor: Color {
        switch license.state {
        case .licensed: Color.success
        case .trialing: Color.brand
        case .trialExpired, .licenseInvalid: Color.warning
        }
    }

    private var licenseStatusSymbol: String {
        switch license.state {
        case .licensed: "checkmark.seal.fill"
        case .trialing: "clock.fill"
        case .trialExpired, .licenseInvalid: "exclamationmark.triangle.fill"
        }
    }

    private func activateLicense() async {
        isActivatingLicense = true
        licenseActionError = nil
        defer { isActivatingLicense = false }
        do {
            try await license.activate(key: licenseKeyInput.trimmingCharacters(in: .whitespaces))
            licenseKeyInput = ""
        } catch {
            licenseActionError = error.localizedDescription
        }
    }

    // MARK: - Hotkeys

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ContentSectionHeader(title: "Hotkeys", symbol: "keyboard")

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
