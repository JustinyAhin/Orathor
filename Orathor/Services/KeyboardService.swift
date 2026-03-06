import Cocoa
import Carbon.HIToolbox

@Observable
final class KeyboardService {
    enum Action {
        case startRecording
        case stopRecording
        case cancelRecording
    }

    var onAction: ((Action) -> Void)?

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
        onAction?(.cancelRecording)
    }

    private func handleFlags(_ event: NSEvent) {
        guard event.keyCode == UInt16(kVK_RightCommand) else { return }
        let cmdDown = event.modifierFlags.contains(.command)

        if cmdDown && !isModifierDown {
            isModifierDown = true
            onKeyDown()
        } else if !cmdDown && isModifierDown {
            isModifierDown = false
            onKeyUp()
        }
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
            onAction?(.startRecording)
            return
        }

        // Start hold detection
        holdCheckTask?.cancel()
        holdCheckTask = Task {
            try? await Task.sleep(nanoseconds: holdThreshold)
            guard !Task.isCancelled, isModifierDown else { return }
            isHolding = true
            onAction?(.startRecording)
        }
    }

    private func onKeyUp() {
        holdCheckTask?.cancel()
        holdCheckTask = nil

        // Release after hold → stop
        if isHolding {
            isHolding = false
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
            onAction?(.stopRecording)
            return
        }

        // Single tap — record time for potential double-tap
        lastTapTime = Date()
    }
}
