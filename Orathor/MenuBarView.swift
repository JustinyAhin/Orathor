import SwiftUI

struct MenuBarView: View {
    @State private var audioService = AudioService()

    var body: some View {
        VStack(spacing: 12) {
            Text("Orathor")
                .font(.headline)

            Button {
                toggleRecording()
            } label: {
                HStack {
                    Image(systemName: audioService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    Text(audioService.isRecording ? "Stop" : "Start Dictation")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .tint(audioService.isRecording ? .red : .accentColor)

            if audioService.isRecording {
                AudioLevelView(level: audioService.audioLevel)
                    .frame(height: 4)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 250)
    }

    private func toggleRecording() {
        if audioService.isRecording {
            audioService.stopRecording()
        } else {
            do {
                try audioService.startRecording()
            } catch {
                print("Failed to start recording: \(error.localizedDescription)")
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
    MenuBarView()
}
