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
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let content = RecordingOverlayView(viewModel: viewModel)
            let hostingView = NSHostingView(rootView: content)
            hostingView.frame.size = hostingView.fittingSize
            p.setContentSize(hostingView.fittingSize)
            p.contentView = hostingView
            panel = p
        }
        positionAtBottomCenter()
        panel?.orderFrontRegardless()
    }

    static func hide() {
        panel?.orderOut(nil)
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

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }

            Text("Recording")
                .font(.system(.callout, weight: .medium))

            if viewModel.recordingMode == .clipboard {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            OverlayLevelBars(level: viewModel.currentAudioLevel)
                .frame(width: 50, height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct OverlayLevelBars: View {
    let level: Float
    private let barCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive(index) ? .green : .secondary.opacity(0.3))
                    .frame(width: 2, height: isActive(index) ? max(3, CGFloat(level) * 16) : 3)
            }
        }
        .animation(.easeOut(duration: 0.05), value: level)
    }

    private func isActive(_ index: Int) -> Bool {
        Float(index) / Float(barCount) < level
    }
}
