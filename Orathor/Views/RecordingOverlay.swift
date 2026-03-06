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
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(Color.borderSubtle, lineWidth: 0.5)
                )
        }
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
                    .fill(
                        active
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [.brand, .brandGradientEnd],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                              )
                            : AnyShapeStyle(Color.textTertiary.opacity(0.3))
                    )
                    .frame(width: 2, height: active ? max(3, CGFloat(level) * 16) : 3)
            }
        }
        .animation(.easeOut(duration: 0.05), value: level)
    }

    private func isActive(_ index: Int) -> Bool {
        Float(index) / Float(barCount) < level
    }
}
