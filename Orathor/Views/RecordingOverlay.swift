import AppKit
import SwiftUI

@Observable
final class RecordingOverlayController {
    enum Mode: Equatable {
        case starting
        case accessibilityPrompt
        case error(String)
        case preparing
        case formatting
        case recording
        case recordingWithFallback
        case transcribingLocally
    }

    enum Presentation: Equatable {
        case idle
        case visible(sessionID: UUID, mode: Mode)
    }

    struct Lifecycle {
        private(set) var presentation: Presentation = .idle

        @discardableResult
        mutating func present(sessionID: UUID, mode: Mode) -> Bool {
            let next = Presentation.visible(sessionID: sessionID, mode: mode)
            guard presentation != next else { return false }
            presentation = next
            return true
        }

        @discardableResult
        mutating func update(mode: Mode, sessionID: UUID) -> Bool {
            guard case .visible(let currentID, let currentMode) = presentation,
                  currentID == sessionID,
                  currentMode != mode else { return false }
            presentation = .visible(sessionID: sessionID, mode: mode)
            return true
        }

        @discardableResult
        mutating func dismiss(sessionID: UUID? = nil) -> Bool {
            guard case .visible(let currentID, _) = presentation,
                  sessionID == nil || sessionID == currentID else { return false }
            presentation = .idle
            return true
        }
    }

    private(set) var lifecycle = Lifecycle()
    private var panel: NSPanel?
    private var layoutTask: Task<Void, Never>?
    private var dismissalTask: Task<Void, Never>?
    private let diag = DiagnosticLogger.shared

    var presentation: Presentation { lifecycle.presentation }

    var currentSessionID: UUID? {
        guard case .visible(let sessionID, _) = presentation else { return nil }
        return sessionID
    }

    func present(
        sessionID: UUID,
        mode: Mode = .starting,
        viewModel: TranscriptionViewModel
    ) {
        dismissalTask?.cancel()
        dismissalTask = nil

        let didChange = lifecycle.present(sessionID: sessionID, mode: mode)
        ensurePanel(viewModel: viewModel)
        guard didChange || panel?.isVisible != true else { return }

        diag.log("Overlay present — session: \(sessionID), mode: \(mode)")
        scheduleLayout(sessionID: sessionID, shouldPresent: true)
    }

    func update(mode: Mode, sessionID: UUID) {
        guard lifecycle.update(mode: mode, sessionID: sessionID) else { return }
        dismissalTask?.cancel()
        dismissalTask = nil
        diag.log("Overlay mode — session: \(sessionID), mode: \(mode)")
        scheduleLayout(sessionID: sessionID, shouldPresent: panel?.isVisible != true)
    }

    func dismiss(sessionID: UUID? = nil) {
        guard lifecycle.dismiss(sessionID: sessionID) else { return }
        layoutTask?.cancel()
        layoutTask = nil
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        diag.log("Overlay dismiss — session: \(sessionID?.uuidString ?? "current")")
    }

    func dismiss(
        after duration: Duration,
        sessionID: UUID,
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        dismissalTask?.cancel()
        dismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }
            guard !Task.isCancelled, self?.currentSessionID == sessionID else { return }
            onDismiss?()
            self?.dismiss(sessionID: sessionID)
        }
    }

    private func ensurePanel(viewModel: TranscriptionViewModel) {
        guard panel == nil else { return }

        let newPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.contentView = NSHostingView(
            rootView: RecordingOverlayView(viewModel: viewModel, controller: self)
        )
        panel = newPanel
    }

    private func scheduleLayout(sessionID: UUID, shouldPresent: Bool) {
        layoutTask?.cancel()
        layoutTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self,
                  !Task.isCancelled,
                  self.currentSessionID == sessionID,
                  let panel = self.panel,
                  let hostingView = panel.contentView as? NSHostingView<RecordingOverlayView>,
                  let screen = NSScreen.main else { return }

            let size = hostingView.fittingSize
            guard size.width > 0, size.height > 0 else { return }
            let screenFrame = screen.visibleFrame
            let frame = NSRect(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.minY + 80,
                width: size.width,
                height: size.height
            )
            if panel.frame != frame {
                panel.setFrame(frame, display: false)
                self.diag.log(
                    "Overlay layout — session: \(sessionID), size: \(Int(size.width))x\(Int(size.height))")
            }
            guard self.currentSessionID == sessionID, !Task.isCancelled else { return }
            if shouldPresent || !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
    }
}

struct RecordingOverlayView: View {
    var viewModel: TranscriptionViewModel
    var controller: RecordingOverlayController
    @State private var isPulsing = false

    @ViewBuilder
    var body: some View {
        switch controller.presentation {
        case .idle:
            EmptyView()
        case .visible(let sessionID, let mode):
            Group {
                switch mode {
                case .starting:
                    startingContent
                case .accessibilityPrompt:
                    accessibilityPromptContent
                case .error(let message):
                    errorContent(message)
                case .preparing:
                    preparingContent
                case .formatting:
                    formattingContent
                case .recording:
                    recordingContent(fallbackPending: false)
                case .recordingWithFallback:
                    recordingContent(fallbackPending: true)
                case .transcribingLocally:
                    transcribingLocallyContent
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
            .id(sessionID)
        }
    }

    private var startingContent: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
            Text("Starting…")
                .font(OType.monoSmall)
                .foregroundStyle(Color.textPrimary)
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

    private var transcribingLocallyContent: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
            Text("Transcribing locally…")
                .font(OType.monoSmall)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func recordingContent(fallbackPending: Bool) -> some View {
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
                    .onDisappear { isPulsing = false }

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

            if fallbackPending {
                Label("Cloud lost · recording continues", systemImage: "wifi.slash")
                    .font(OType.monoMicro)
                    .foregroundStyle(Color.warning)
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
    let level: AudioMeterLevel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<AudioMeterLevel.stepCount, id: \.self) { index in
                let active = index < level.step
                RoundedRectangle(cornerRadius: 1)
                    .fill(active ? Color.recording : Color.textTertiary.opacity(0.25))
                    .frame(width: 2, height: active ? activeHeight : 3)
            }
        }
    }

    private var activeHeight: CGFloat {
        max(3, CGFloat(level.normalized) * 16)
    }
}
