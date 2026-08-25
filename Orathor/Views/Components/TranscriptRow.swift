import SwiftUI

struct TranscriptRow: View {
    let entry: TranscriptEntry
    var searchText: String = ""
    let historyService: TranscriptHistoryService
    let playbackService: AudioPlaybackService
    var lineLimit: Int = 2
    var compact: Bool = false

    @State private var isHovered = false
    @State private var didCopy = false

    private var textFont: Font { compact ? OType.callout : OType.body }
    private var status: TranscriptStatus { entry.status ?? .complete }
    private var displayText: String {
        status == .failed ? "Transcription failed · audio saved" : entry.text
    }
    private var usedFallback: Bool {
        entry.requestedEngine != nil && entry.requestedEngine != entry.engine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                appIconAndName
                Spacer()
                trailingInfo
            }

            Text(highlightedText)
                .font(textFont)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered && !didCopy {
                actionBar
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(didCopy ? Color.indicatorGreen.opacity(0.4) : (isHovered ? Color.borderSubtle : .clear), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if status != .failed { copy() }
        }
        .pointerStyle(status == .failed ? .default : .link)
        .help(status == .failed ? "Audio recording preserved" : "Click to copy")
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.18), value: didCopy)
    }

    private var rowBackground: Color {
        if didCopy { return Color.indicatorGreen.opacity(0.1) }
        return isHovered ? Color.surfaceSecondary : .clear
    }

    @ViewBuilder
    private var trailingInfo: some View {
        if didCopy {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "checkmark.circle.fill")
                Text("Copied")
            }
            .font(OType.monoMicro)
            .foregroundStyle(Color.indicatorGreen)
            .transition(.opacity)
        } else {
            metadata
        }
    }

    private var highlightedText: AttributedString {
        TextHighlighter.highlight(displayText, query: searchText)
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
            if status == .partial {
                Text("Partial")
                    .foregroundStyle(Color.warning)
                Text("\u{2022}")
            } else if status == .failed {
                Text("Failed")
                    .foregroundStyle(Color.warning)
                Text("\u{2022}")
            } else if usedFallback {
                Text("Apple fallback")
                    .foregroundStyle(Color.warning)
                Text("\u{2022}")
            }
            let seconds = Int(entry.durationSeconds)
            Text("\(seconds)s")
            Text("\u{2022}")
            Text("\(entry.wordCount) words")
            Text("\u{2022}")
            Text(entry.timestamp, style: .relative)
        }
        .font(OType.monoMicro)
        .foregroundStyle(Color.textTertiary)
    }

    private var actionBar: some View {
        HStack(spacing: Spacing.sm) {
            Spacer()
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

                    Divider()
                }

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
            .fixedSize()
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        withAnimation { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { didCopy = false }
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
