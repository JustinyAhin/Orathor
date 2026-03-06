import SwiftUI
import Carbon.HIToolbox

struct HotkeyField: View {
    let label: String
    @Binding var hotkey: HotkeyModifier
    @State private var isListening = false
    @State private var flagsMonitor: Any?
    @State private var escapeMonitor: Any?

    var body: some View {
        LabeledContent(label) {
            Button {
                if isListening { stopListening() } else { startListening() }
            } label: {
                if isListening {
                    listeningLabel
                } else {
                    keyCaps(hotkey.keySymbols)
                }
            }
            .buttonStyle(.plain)
            .hotkeyFieldStyle(isListening: isListening)
        }
    }

    private func startListening() {
        isListening = true
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if let matched = HotkeyModifier.from(keyCode: event.keyCode) {
                hotkey = matched
                stopListening()
            }
            return event
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stopListening(); return nil }
            return event
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if isListening { stopListening() }
        }
    }

    private func stopListening() {
        isListening = false
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        flagsMonitor = nil
        escapeMonitor = nil
    }
}

struct OptionalHotkeyField: View {
    let label: String
    @Binding var hotkey: HotkeyModifier?
    @State private var isListening = false
    @State private var flagsMonitor: Any?
    @State private var escapeMonitor: Any?

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: Spacing.xs) {
                Button {
                    if isListening { stopListening() } else { startListening() }
                } label: {
                    if isListening {
                        listeningLabel
                    } else if let hotkey {
                        keyCaps(hotkey.keySymbols)
                    } else {
                        Text("Not set")
                            .font(OType.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .hotkeyFieldStyle(isListening: isListening)

                if hotkey != nil {
                    Button {
                        hotkey = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove hotkey")
                }
            }
        }
    }

    private func startListening() {
        isListening = true
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if let matched = HotkeyModifier.from(keyCode: event.keyCode) {
                hotkey = matched
                stopListening()
            }
            return event
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stopListening(); return nil }
            return event
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if isListening { stopListening() }
        }
    }

    private func stopListening() {
        isListening = false
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        flagsMonitor = nil
        escapeMonitor = nil
    }
}

// MARK: - Shared helpers

private var listeningLabel: some View {
    Text("Press a key...")
        .font(OType.caption)
        .foregroundStyle(Color.textSecondary)
}

private func keyCaps(_ symbols: [String]) -> some View {
    HStack(spacing: Spacing.xxs) {
        ForEach(symbols, id: \.self) { symbol in
            Text(symbol)
                .font(OType.captionMedium)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(Color.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .stroke(Color.borderDefault, lineWidth: 0.5)
                )
        }
    }
}

private extension View {
    func hotkeyFieldStyle(isListening: Bool) -> some View {
        self
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(isListening ? Color.brand.opacity(0.08) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .stroke(isListening ? Color.brand.opacity(0.4) : .clear, lineWidth: 1)
            )
    }
}
