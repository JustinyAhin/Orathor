import SwiftUI

struct MenuBarView: View {
    var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcriptList
            Divider()
            footer
        }
        .frame(width: 320)
        .task {
            viewModel.setUp()
            await viewModel.checkPermissions()
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

    private var transcriptList: some View {
        Group {
            if viewModel.historyService.entries.isEmpty {
                VStack(spacing: 8) {
                    Text("No transcripts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Press Right \u{2318} to start dictating")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.historyService.entries) { entry in
                            TranscriptEntryRow(entry: entry)
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
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        Button {
            copyText()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    appIconAndName
                    Spacer()
                    metadata
                }

                Text(entry.text)
                    .font(.system(.callout))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showCopied {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
