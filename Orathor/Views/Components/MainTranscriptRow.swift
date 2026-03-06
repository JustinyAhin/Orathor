import SwiftUI

struct MainTranscriptRow: View {
    let entry: TranscriptEntry
    let searchText: String
    let historyService: TranscriptHistoryService
    let playbackService: AudioPlaybackService

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(OType.monoSmall)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    appIcon
                    if let appName = entry.targetAppName {
                        Text(appName)
                            .font(OType.captionMedium)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("\u{2022}")
                        .foregroundStyle(Color.borderDefault)
                        .font(OType.micro)
                    Text("\(entry.wordCount)w")
                        .font(OType.monoMicro)
                        .foregroundStyle(Color.textTertiary)
                }

                Text(TextHighlighter.highlight(entry.text, query: searchText))
                    .font(OType.body)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            if isHovered {
                actionButtons
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(isHovered ? Color.surfaceSecondary : .clear)
        )
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
        HStack(spacing: Spacing.xxxs) {
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
        }
        .buttonStyle(IconButtonStyle())
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
