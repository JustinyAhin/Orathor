import Cocoa
import Carbon.HIToolbox

@Observable
final class KeyboardService {
    enum RecordingMode {
        case insertAtCursor
        case clipboard
    }

    enum Action {
        case startRecording(RecordingMode)
        case stopRecording
        case cancelRecording
    }

    var onAction: ((Action) -> Void)?
    var insertHotkey: HotkeyModifier = .rightOption
    var clipboardHotkey: HotkeyModifier?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var isModifierDown = false
    private var lastTapTime: Date?
    private var isHolding = false
    private var isToggled = false
    private var justToggledOn = false
    private var holdCheckTask: Task<Void, Never>?
    private var activeHotkey: HotkeyModifier?

    private let holdThreshold: UInt64 = 300_000_000 // 300ms
    private let doubleTapWindow: TimeInterval = 0.4

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFlags(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFlags(event)
            }
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleKeyDown(event)
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleKeyDown(event)
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        globalMonitor = nil
        localMonitor = nil
        globalKeyMonitor = nil
        localKeyMonitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard event.keyCode == UInt16(kVK_Escape), isToggled else { return }
        isToggled = false
        justToggledOn = false
        SoundService.playCancel()
        onAction?(.cancelRecording)
    }

    private func handleFlags(_ event: NSEvent) {
        let matchedHotkey: HotkeyModifier
        if event.keyCode == insertHotkey.keyCode {
            matchedHotkey = insertHotkey
        } else if let ch = clipboardHotkey, event.keyCode == ch.keyCode {
            matchedHotkey = ch
        } else {
            return
        }

        let isDown = event.modifierFlags.contains(matchedHotkey.modifierFlag)

        if isDown && !isModifierDown {
            isModifierDown = true
            activeHotkey = matchedHotkey
            onKeyDown()
        } else if !isDown && isModifierDown {
            isModifierDown = false
            onKeyUp()
        }
    }

    private var activeMode: RecordingMode {
        if let activeHotkey, let ch = clipboardHotkey, activeHotkey == ch {
            return .clipboard
        }
        return .insertAtCursor
    }

    private func onKeyDown() {
        // Already in toggle mode — next release will stop
        if isToggled && !justToggledOn {
            return
        }

        // Double-tap detection: second press within window
        if let last = lastTapTime, Date().timeIntervalSince(last) < doubleTapWindow {
            lastTapTime = nil
            isToggled = true
            justToggledOn = true
            SoundService.playStart()
            onAction?(.startRecording(activeMode))
            return
        }

        // Start hold detection
        holdCheckTask?.cancel()
        holdCheckTask = Task {
            try? await Task.sleep(nanoseconds: holdThreshold)
            guard !Task.isCancelled, isModifierDown else { return }
            isHolding = true
            SoundService.playStart()
            onAction?(.startRecording(activeMode))
        }
    }

    private func onKeyUp() {
        holdCheckTask?.cancel()
        holdCheckTask = nil

        // Release after hold → stop
        if isHolding {
            isHolding = false
            SoundService.playStop()
            onAction?(.stopRecording)
            return
        }

        // Release after double-tap start → ignore (keep recording)
        if justToggledOn {
            justToggledOn = false
            return
        }

        // Press in toggle mode → stop
        if isToggled {
            isToggled = false
            SoundService.playStop()
            onAction?(.stopRecording)
            return
        }

        // Single tap — record time for potential double-tap
        lastTapTime = Date()
    }
}
