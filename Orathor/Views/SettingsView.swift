import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Speech Engine")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Engine", selection: $viewModel.selectedEngine) {
                ForEach(SpeechEngine.allCases) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(viewModel.selectedEngine.description)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if viewModel.selectedEngine == .deepgram {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("API Key", text: $viewModel.deepgramApiKey)
                        .textFieldStyle(.roundedBorder)

                    if viewModel.isDeepgramConfigured {
                        Label("API key saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedEngine)
    }
}
