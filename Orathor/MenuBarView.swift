import SwiftUI

struct MenuBarView: View {
    var viewModel: TranscriptionViewModel
    @State private var playbackService = AudioPlaybackService()
    @State private var searchText = ""
    @State private var escapeMonitor: Any?

    private var filteredEntries: [TranscriptEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return viewModel.historyService.entries }
        return viewModel.historyService.entries.filter { entry in
            entry.text.localizedCaseInsensitiveContains(query)
            || (entry.targetAppName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            transcriptList
            Divider()
            footer
        }
        .frame(width: 320)
        .task {
            viewModel.setUp()
            await viewModel.checkPermissions()
        }
        .onAppear {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // Escape
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
        HStack {
            Text("Recent transcripts")
                .font(.headline)
            Spacer()
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Recording...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search transcripts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var transcriptList: some View {
        Group {
            if viewModel.historyService.entries.isEmpty {
                VStack(spacing: 8) {
                    Text("No transcripts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Press \(viewModel.settingsViewModel.insertHotkey.displayName) to start dictating")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if filteredEntries.isEmpty {
                Text("No matching transcripts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredEntries) { entry in
                            TranscriptEntryRow(
                                entry: entry,
                                searchText: searchText,
                                historyService: viewModel.historyService,
                                playbackService: playbackService
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            HStack {
                DisclosureGroup("Settings") {
                    SettingsView(viewModel: viewModel.settingsViewModel)
                        .padding(.top, 4)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                appIconAndName
                Spacer()
                metadata
            }

            Text(highlightedText)
                .font(.system(.callout))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if showCopied {
                Text("Copied!")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            actionBar
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .onHover { isHovered = $0 }
    }

    private var highlightedText: AttributedString {
        var result = AttributedString(entry.text)
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return result }
        var searchRange = result.startIndex..<result.endIndex
        while let range = result[searchRange].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            result[range].backgroundColor = .yellow.opacity(0.7)
            searchRange = range.upperBound..<result.endIndex
        }
        return result
    }

    @ViewBuilder
    private var appIconAndName: some View {
        HStack(spacing: 6) {
            if let bundleID = entry.targetAppBundleID,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path()))
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            if let appName = entry.targetAppName {
                Text(appName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            let seconds = Int(entry.durationSeconds)
            Text("\(seconds)s")
            Text("\u{2022}")
            Text("\(entry.wordCount) words")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Spacer()

            rowButton("doc.on.doc", help: "Copy text") {
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
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }

    private func rowButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        NSWorkspace.shared.selectFile(url.path(), inFileViewerRootedAtPath: "")
    }
}

struct AudioLevelView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(.green.gradient)
                .frame(width: geometry.size.width * CGFloat(level))
                .animation(.easeOut(duration: 0.05), value: level)
        }
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(.secondary.opacity(0.2))
        )
    }
}

#Preview {
    MenuBarView(viewModel: TranscriptionViewModel())
}
