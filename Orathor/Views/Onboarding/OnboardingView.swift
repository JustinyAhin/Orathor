import SwiftUI

/// First-run welcome flow: welcome → permissions → try it. Auto-presented on
/// first launch (see the "onboarding" scene in OrathorApp); closing the window
/// at any point counts as done — Settings has a "Show welcome guide" re-open path.
struct OnboardingView: View {
    var viewModel: TranscriptionViewModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step: Step = .welcome
    @State private var didPromptAccessibility = false
    @State private var initialHistoryCount = 0
    @State private var tryItText = ""
    @FocusState private var tryItFieldFocused: Bool

    private enum Step: Int, CaseIterable {
        case welcome
        case permissions
        case tryIt
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bottomBar
        }
        .frame(width: 520, height: 540)
        .background(Color.surfacePrimary)
        .task {
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            hasCompletedOnboarding = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .permissions:
            permissionsStep
        case .tryIt:
            tryItStep
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            WaveformAccent(amplitude: 4, wavelength: 12, lineWidth: 1.5, animated: true)
                .frame(width: 140)
            VStack(spacing: Spacing.sm) {
                Text("Welcome to Orathor")
                    .font(OType.greeting)
                    .foregroundStyle(Color.textPrimary)
                (Text("Hold ")
                    + Text(viewModel.settingsViewModel.insertHotkey.displayName)
                        .foregroundColor(.brand)
                        .fontWeight(.medium)
                    + Text(", speak, and your words appear wherever your cursor is."))
                    .font(OType.summary)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepHeader(
                "Permissions",
                "Orathor needs three permissions to dictate anywhere on your Mac."
            )

            VStack(spacing: 0) {
                PermissionRow(
                    title: "Microphone",
                    caption: "Hears your voice while you dictate",
                    symbol: "mic.fill",
                    status: viewModel.permissions.microphone,
                    grant: { Task { await viewModel.permissions.requestMicrophone() } },
                    openSettings: PermissionsService.openMicrophoneSettings
                )
                SubtleDivider()
                PermissionRow(
                    title: "Speech recognition",
                    caption: "Turns your speech into text on-device",
                    symbol: "waveform",
                    status: viewModel.permissions.speechRecognition,
                    grant: { Task { await viewModel.permissions.requestSpeechRecognition() } },
                    openSettings: PermissionsService.openSpeechSettings
                )
                SubtleDivider()
                PermissionRow(
                    title: "Accessibility",
                    caption: "Lets Orathor type for you — enable Orathor in the list, no restart needed",
                    symbol: "accessibility",
                    status: accessibilityStatus,
                    grant: {
                        viewModel.permissions.promptAccessibility()
                        didPromptAccessibility = true
                    },
                    openSettings: PermissionsService.openAccessibilitySettings
                )
            }
            .cardStyle(padding: 0)
        }
        .padding(Spacing.xxxl)
        .task { await viewModel.permissions.pollWhileVisible() }
    }

    /// AX has no notDetermined state — show "Grant" until the system prompt
    /// has been fired once, then point at System Settings.
    private var accessibilityStatus: PermissionsService.Status {
        if viewModel.permissions.accessibility { return .granted }
        return didPromptAccessibility ? .denied : .notDetermined
    }

    // MARK: - Try it

    private var tryItStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepHeader(
                "Try your first dictation",
                "Hold the key, speak, release — your words land at the cursor."
            )

            HStack(spacing: Spacing.sm) {
                Text(viewModel.settingsViewModel.insertHotkey.displayName)
                    .font(OType.mono)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
                Text("Hold to record, release to insert")
                    .font(OType.caption)
                    .foregroundStyle(Color.textTertiary)
            }

            TextEditor(text: $tryItText)
                .font(OType.body)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(Spacing.sm)
                .frame(height: 120)
                .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .stroke(Color.borderSubtle, lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if tryItText.isEmpty {
                        Text("Try dictating here…")
                            .font(OType.body)
                            .foregroundStyle(Color.textTertiary)
                            .padding(Spacing.md)
                            .allowsHitTesting(false)
                    }
                }
                .focused($tryItFieldFocused)

            tryItStatus
        }
        .padding(Spacing.xxxl)
        .onAppear {
            initialHistoryCount = viewModel.historyService.entries.count
            tryItFieldFocused = true
        }
    }

    private var hasDictated: Bool {
        viewModel.historyService.entries.count > initialHistoryCount
    }

    @ViewBuilder
    private var tryItStatus: some View {
        if viewModel.isRecording {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(Color.recording)
                    .frame(width: 6, height: 6)
                Text("Listening…")
                    .font(OType.caption)
                    .foregroundStyle(Color.recording)
                AudioLevelView(level: viewModel.currentAudioLevel)
                    .frame(width: 60, height: 4)
            }
        } else if hasDictated {
            if viewModel.needsAccessibilityPrompt {
                Label(
                    "Copied to clipboard — grant Accessibility to insert automatically",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(OType.caption)
                .foregroundStyle(Color.warning)
            } else {
                Label("You're set", systemImage: "checkmark.circle.fill")
                    .font(OType.caption)
                    .foregroundStyle(Color.success)
            }
        }
    }

    // MARK: - Chrome

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(OType.title)
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .font(OType.body)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var bottomBar: some View {
        ZStack {
            HStack(spacing: Spacing.xs) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s == step ? Color.brand : Color.textTertiary.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }

            HStack {
                if step != .welcome {
                    Button("Back") {
                        goTo(step.rawValue - 1)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                Spacer()
                nextButton
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .overlay(alignment: .top) { SubtleDivider() }
    }

    @ViewBuilder
    private var nextButton: some View {
        switch step {
        case .welcome:
            Button("Continue") { goTo(step.rawValue + 1) }
                .buttonStyle(.borderedProminent)
        case .permissions:
            if viewModel.permissions.allGranted {
                Button("Continue") { goTo(step.rawValue + 1) }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Skip for now") { goTo(step.rawValue + 1) }
                    .buttonStyle(GhostButtonStyle())
            }
        case .tryIt:
            Button("Finish") {
                hasCompletedOnboarding = true
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func goTo(_ rawValue: Int) {
        guard let next = Step(rawValue: rawValue) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            step = next
        }
    }
}
