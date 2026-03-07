import SwiftUI

struct MenuBarView: View {
    var viewModel: TranscriptionViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var playbackService = AudioPlaybackService()
    @State private var searchText = ""
    @State private var escapeMonitor: Any?

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
            footer
        }
        .frame(width: 340)
        .task {
            await viewModel.checkPermissions()
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
                HStack {
                    Text("Recents")
                        .sectionHeaderStyle()
                    Spacer()
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
                            TranscriptEntryRow(
                                entry: entry,
                                searchText: searchText,
                                historyService: viewModel.historyService,
                                playbackService: playbackService
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

    private var footer: some View {
        HStack {
            Button("Open Orathor") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(GhostButtonStyle())
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
}

struct TranscriptEntryRow: View {
    let entry: TranscriptEntry
    let searchText: String
    let historyService: TranscriptHistoryService
    let playbackService: AudioPlaybackService

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.brand)
                .frame(width: 2)
                .padding(.vertical, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    appIconAndName
                    Spacer()
                    metadata
                }

                Text(highlightedText)
                    .font(OType.callout)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if isHovered {
                    actionBar
                        .transition(.opacity)
                }
            }
            .padding(.leading, Spacing.sm)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(isHovered ? Color.surfaceSecondary : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var highlightedText: AttributedString {
        TextHighlighter.highlight(entry.text, query: searchText)
    }

    @ViewBuilder
    private var appIconAndName: some View {
        HStack(spacing: Spacing.xs) {
            if let bundleID = entry.targetAppBundleID,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path()))
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            if let appName = entry.targetAppName {
                Text(appName)
                    .font(OType.captionMedium)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: Spacing.xxs) {
            let seconds = Int(entry.durationSeconds)
            Text("\(seconds)s")
            Text("\u{2022}")
            Text("\(entry.wordCount)w")
        }
        .font(OType.monoMicro)
        .foregroundStyle(Color.textTertiary)
    }

    private var actionBar: some View {
        HStack(spacing: Spacing.sm) {
            Spacer()

            rowButton(showCopied ? "checkmark" : "doc.on.doc", help: "Copy text") {
                copyText()
            }

            Menu {
                if historyService.audioFileURL(for: entry) != nil {
                    Button {
                        togglePlayback()
                    } label: {
                        Label(
                            playbackService.isPlaying ? "Stop" : "Play",
                            systemImage: playbackService.isPlaying ? "stop.fill" : "play.fill"
                        )
                    }

                    Button {
                        showInFinder()
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    historyService.delete(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }

    private func rowButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
        }
        .buttonStyle(IconButtonStyle(size: 22))
        .help(help)
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func togglePlayback() {
        if playbackService.isPlaying {
            playbackService.stop()
        } else if let url = historyService.audioFileURL(for: entry) {
            playbackService.play(url: url)
        }
    }

    private func showInFinder() {
        guard let url = historyService.audioFileURL(for: entry) else { return }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}

struct AudioLevelView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient.brand)
                .frame(width: geometry.size.width * CGFloat(level))
                .animation(.easeOut(duration: 0.05), value: level)
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
