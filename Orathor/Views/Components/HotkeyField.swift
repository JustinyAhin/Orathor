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
            HStack(spacing: 6) {
                Button {
                    if isListening { stopListening() } else { startListening() }
                } label: {
                    if isListening {
                        listeningLabel
                    } else if let hotkey {
                        keyCaps(hotkey.keySymbols)
                    } else {
                        Text("Not set")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
                            .foregroundStyle(.secondary)
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
        .font(.caption)
        .foregroundStyle(.secondary)
}

private func keyCaps(_ symbols: [String]) -> some View {
    HStack(spacing: 4) {
        ForEach(symbols, id: \.self) { symbol in
            Text(symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.primary.opacity(0.15), lineWidth: 0.5)
                )
        }
    }
}

private extension View {
    func hotkeyFieldStyle(isListening: Bool) -> some View {
        self
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isListening ? Color.accentColor.opacity(0.1) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isListening ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
            )
    }
}
