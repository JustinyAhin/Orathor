import SwiftUI

struct MenuBarView: View {
    var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Orathor")
                .font(.headline)

            Button {
                viewModel.toggleRecording()
            } label: {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    Text(viewModel.isRecording ? "Stop" : "Start Dictation")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .tint(viewModel.isRecording ? .red : .accentColor)

            if viewModel.isRecording {
                AudioLevelView(level: viewModel.currentAudioLevel)
                    .frame(height: 4)
            }

            if !viewModel.currentTranscription.isEmpty {
                ScrollView {
                    Text(viewModel.currentTranscription)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 150)

                HStack {
                    Button {
                        viewModel.insertAtCursor()
                    } label: {
                        Label("Insert at Cursor", systemImage: "text.insert")
                    }

                    Button {
                        viewModel.copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .controlSize(.small)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 250)
        .task {
            viewModel.setUp()
            await viewModel.checkPermissions()
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
