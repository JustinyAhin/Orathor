import SwiftUI

struct MainTranscriptRow: View {
    let entry: TranscriptEntry
    let searchText: String
    let historyService: TranscriptHistoryService
    let playbackService: AudioPlaybackService

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    appIcon
                    if let appName = entry.targetAppName {
                        Text(appName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    Text("\u{2022}")
                        .foregroundStyle(.quaternary)
                        .font(.caption2)
                    Text("\(entry.wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(TextHighlighter.highlight(entry.text, query: searchText))
                    .font(.subheadline)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            // Actions — hover only
            if isHovered {
                actionButtons
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let bundleID = entry.targetAppBundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path()))
                .resizable()
                .frame(width: 14, height: 14)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            iconButton(showCopied ? "checkmark" : "doc.on.doc", help: "Copy") {
                copyText()
            }

            if historyService.audioFileURL(for: entry) != nil {
                iconButton(playbackService.isPlaying ? "stop.fill" : "play.fill",
                          help: playbackService.isPlaying ? "Stop" : "Play") {
                    togglePlayback()
                }
                iconButton("folder", help: "Show in Finder") {
                    showInFinder()
                }
            }

            iconButton("trash", help: "Delete") {
                historyService.delete(entry)
            }
        }
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
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
