import OrathorLicensing
import SwiftUI

struct MenuBarView: View {
    var viewModel: TranscriptionViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var playbackService = AudioPlaybackService()
    @State private var searchText = ""
    @State private var escapeMonitor: Any?
    @State private var formattingAvailable = true

    private var filteredEntries: [TranscriptEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let source = viewModel.historyService.entries
        if query.isEmpty {
            return Array(source.prefix(15))
        }
        return Array(source.filter { entry in
            entry.text.localizedCaseInsensitiveContains(query)
            || (entry.targetAppName?.localizedCaseInsensitiveContains(query) ?? false)
        }.prefix(15))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = viewModel.errorMessage, !viewModel.isRecording {
                errorBanner(error)
            }
            SubtleDivider()
            searchBar
            transcriptList
            SubtleDivider()
            if viewModel.license.isGated, let trialStatus {
                trialStatusLine(trialStatus)
                SubtleDivider()
            }
            footer
        }
        .frame(width: 340)
        .task {
            await viewModel.checkPermissions()
            formattingAvailable = TranscriptPolisher.status.available
        }
        .onAppear {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    NSApp.keyWindow?.close()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = escapeMonitor {
                NSEvent.removeMonitor(monitor)
                escapeMonitor = nil
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            if viewModel.isRecording {
                HStack(spacing: Spacing.sm) {
                    recordingBadge
                    Spacer()
                    AudioLevelView(level: viewModel.currentAudioLevel)
                        .frame(width: 60, height: 4)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

                WaveformAccent(amplitude: 2, wavelength: 8, lineWidth: 1, animated: true)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xs)
            } else {
                HStack(spacing: Spacing.xs) {
                    ContentSectionHeader(title: "Recents", symbol: "clock")
                    Spacer()
                    smartFormattingToggle
                    enginePicker
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(Color.recording)
                .frame(width: 6, height: 6)
            Text("REC")
                .font(OType.monoMicro)
        }
        .foregroundStyle(Color.recording)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(Color.recording.opacity(0.12), in: Capsule())
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.warning)
                .font(.system(size: 11))
            Text(message)
                .font(OType.caption)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.warning.opacity(0.1))
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
            TextField("Search transcripts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(OType.body)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var transcriptList: some View {
        Group {
            if viewModel.historyService.entries.isEmpty {
                VStack(spacing: Spacing.md) {
                    WaveformAccent(amplitude: 3, wavelength: 12, lineWidth: 1.5)
                        .frame(width: 80)
                        .opacity(0.3)
                    Text("Ready to go")
                        .font(OType.body)
                        .foregroundStyle(Color.textSecondary)
                    Text("Press \(viewModel.settingsViewModel.insertHotkey.displayName) to start")
                        .font(OType.monoSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxl)
            } else if filteredEntries.isEmpty {
                Text("No matching transcripts")
                    .font(OType.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxxl)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xxxs) {
                        ForEach(filteredEntries) { entry in
                            TranscriptRow(
                                entry: entry,
                                searchText: searchText,
                                historyService: viewModel.historyService,
                                playbackService: playbackService,
                                compact: true
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private var trialStatus: (message: String, isWarning: Bool)? {
        switch viewModel.license.state {
        case .trialing(let daysLeft):
            (daysLeft == 1 ? "Trial — 1 day left" : "Trial — \(daysLeft) days left", false)
        case .trialExpired:
            ("Trial ended — enter a license key in Settings", true)
        case .licenseInvalid:
            ("License problem — check Settings", true)
        case .licensed:
            nil
        }
    }

    private func trialStatusLine(_ status: (message: String, isWarning: Bool)) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: status.isWarning ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.system(size: 9))
            Text(status.message)
                .font(OType.caption)
            Spacer()
        }
        .foregroundStyle(status.isWarning ? Color.warning : Color.brand)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
    }

    private var footer: some View {
        HStack {
            Button("Open Orathor") {
                NSApp.keyWindow?.close()
                if viewModel.settingsViewModel.showInDock {
                    NSApp.setActivationPolicy(.regular)
                }
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(GhostButtonStyle())
            Spacer()
            if viewModel.settingsViewModel.selectedEngine == .deepgram || viewModel.settingsViewModel.selectedEngine == .openAIWhisper {
                languagePicker
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(GhostButtonStyle())
            .keyboardShortcut("q")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var smartFormattingToggle: some View {
        Button {
            viewModel.settingsViewModel.smartFormattingEnabled.toggle()
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 11))
                .foregroundStyle(viewModel.settingsViewModel.smartFormattingEnabled ? Color.brand : Color.textTertiary)
                .frame(height: 16)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Color.surfaceSecondary, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!formattingAvailable)
        .opacity(formattingAvailable ? 1 : 0.4)
        .help(
            formattingAvailable
                ? (viewModel.settingsViewModel.smartFormattingEnabled ? "Smart formatting on" : "Smart formatting off")
                : "Smart formatting unavailable on this Mac"
        )
    }

    private var enginePicker: some View {
        Menu {
            ForEach(SpeechEngine.allCases) { engine in
                Toggle(engine.displayName, isOn: Binding(
                    get: { viewModel.settingsViewModel.selectedEngine == engine },
                    set: { if $0 { viewModel.settingsViewModel.selectedEngine = engine } }
                ))
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brand)
                Text(viewModel.settingsViewModel.selectedEngine.compactName)
                    .font(OType.captionMedium)
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.surfaceSecondary, in: Capsule())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var languagePicker: some View {
        Menu {
            ForEach(DeepgramLanguage.allOptions, id: \.code) { lang in
                Toggle(lang.label, isOn: Binding(
                    get: { viewModel.settingsViewModel.transcriptionLanguage == lang.code },
                    set: { if $0 { viewModel.settingsViewModel.transcriptionLanguage = lang.code } }
                ))
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brand)
                Text(currentLanguageLabel)
                    .font(OType.captionMedium)
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.surfaceSecondary, in: Capsule())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var currentLanguageLabel: String {
        DeepgramLanguage.allOptions.first { $0.code == viewModel.settingsViewModel.transcriptionLanguage }?.label ?? "Auto-detect"
    }
}

struct AudioLevelView: View {
    let level: AudioMeterLevel

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.recording)
                .frame(width: geometry.size.width * CGFloat(level.normalized))
        }
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.textTertiary.opacity(0.2))
        )
    }
}

#Preview {
    MenuBarView(viewModel: TranscriptionViewModel())
}
