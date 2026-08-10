import SwiftUI
import AppKit

enum RecordingOverlay {
    private static var panel: NSPanel?

    static func show(viewModel: TranscriptionViewModel) {
        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let content = RecordingOverlayView(viewModel: viewModel)
            let hostingView = NSHostingView(rootView: content)
            p.contentView = hostingView
            panel = p
        }

        refreshLayout()
        panel?.orderFrontRegardless()
    }

    static func hide() {
        panel?.orderOut(nil)
    }

    static func refreshLayout() {
        guard let panel else { return }
        if let hostingView = panel.contentView as? NSHostingView<RecordingOverlayView> {
            let size = hostingView.fittingSize
            hostingView.frame.size = size
            panel.setContentSize(size)
        }
        positionAtBottomCenter()
    }

    private static func positionAtBottomCenter() {
        guard let panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.minY + 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct RecordingOverlayView: View {
    var viewModel: TranscriptionViewModel
    @State private var isPulsing = false

    private enum Mode: Equatable {
        case accessibilityPrompt
        case error(String)
        case preparing
        case formatting
        case recording
    }

    private var mode: Mode {
        if viewModel.needsAccessibilityPrompt { return .accessibilityPrompt }
        if let error = viewModel.errorMessage, !viewModel.isRecording { return .error(error) }
        if viewModel.isPreparingModel { return .preparing }
        if viewModel.isFormatting { return .formatting }
        return .recording
    }

    var body: some View {
        Group {
            switch mode {
            case .accessibilityPrompt:
                accessibilityPromptContent
            case .error(let message):
                errorContent(message)
            case .preparing:
                preparingContent
            case .formatting:
                formattingContent
            case .recording:
                recordingContent
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(Color.borderSubtle, lineWidth: 0.5)
                )
        }
        .fixedSize()
        .onChange(of: mode) {
            // Defer so the panel measures the newly committed content
            Task { @MainActor in
                RecordingOverlay.refreshLayout()
            }
        }
    }

    private var accessibilityPromptContent: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.warning)
                .font(.system(size: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility permission required")
                    .font(OType.monoSmall)
                    .foregroundStyle(Color.textPrimary)
                Text("Text copied to clipboard instead")
                    .font(OType.monoMicro)
                    .foregroundStyle(Color.textTertiary)
            }
            Button("Open Settings") {
                TextInsertionService.openAccessibilitySettings()
                viewModel.dismissAccessibilityPrompt()
            }
            .font(OType.monoSmall)
            .buttonStyle(.plain)
            .foregroundStyle(Color.brand)
        }
    }

    private func errorContent(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.warning)
                .font(.system(size: 11))
            Text(message)
                .font(OType.monoSmall)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: 300)
    }

    private var preparingContent: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
            Text("Preparing language…")
                .font(OType.monoSmall)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var formattingContent: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
            Text("Formatting…")
                .font(OType.monoSmall)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var recordingContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(Color.recording)
                    .frame(width: 6, height: 6)
                    .opacity(isPulsing ? 0.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear { isPulsing = true }

                Text("REC")
                    .font(OType.monoSmall)
                    .foregroundStyle(Color.textPrimary)

                if viewModel.recordingMode == .clipboard {
                    Text("CLIP")
                        .font(OType.monoMicro)
                        .foregroundStyle(Color.textTertiary)
                }

                OverlayLevelBars(level: viewModel.currentAudioLevel)
                    .frame(width: 50, height: 16)
            }

            transcriptPreview
        }
    }

    // Fixed two-line area so the panel never resizes while streaming. The text
    // is bottom-anchored and clipped from the top so the latest words stay
    // visible — multiline head truncation is unreliable in SwiftUI
    private var transcriptPreview: some View {
        Text(verbatim: " \n ")
            .font(OType.monoSmall)
            .hidden()
            .frame(width: 340, alignment: .topLeading)
            .overlay(alignment: .bottomLeading) {
                Text(viewModel.currentTranscription.isEmpty ? "Listening…" : viewModel.currentTranscription)
                    .font(OType.monoSmall)
                    .foregroundStyle(viewModel.currentTranscription.isEmpty ? Color.textTertiary : Color.textPrimary)
                    .frame(width: 340, alignment: .leading)
                    // Take the full wrapped height — the overlay otherwise
                    // proposes the two-line height and Text tail-truncates
                    .fixedSize(horizontal: false, vertical: true)
            }
            .clipped()
    }
}

private struct OverlayLevelBars: View {
    let level: Float
    private let barCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let active = isActive(index)
                RoundedRectangle(cornerRadius: 1)
                    .fill(active ? Color.recording : Color.textTertiary.opacity(0.25))
                    .frame(width: 2, height: active ? max(3, CGFloat(level) * 16) : 3)
            }
        }
        .animation(.easeOut(duration: 0.05), value: level)
    }

    private func isActive(_ index: Int) -> Bool {
        Float(index) / Float(barCount) < level
    }
}
