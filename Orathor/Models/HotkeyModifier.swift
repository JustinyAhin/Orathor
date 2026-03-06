import Carbon.HIToolbox
import AppKit

enum HotkeyModifier: String, CaseIterable, Identifiable, Codable {
    case rightCommand = "rightCommand"
    case rightOption = "rightOption"
    case rightControl = "rightControl"
    case rightShift = "rightShift"
    case fn = "fn"

    var id: String { rawValue }

    var keyCode: UInt16 {
        switch self {
        case .rightCommand: UInt16(kVK_RightCommand)
        case .rightOption: UInt16(kVK_RightOption)
        case .rightControl: UInt16(kVK_RightControl)
        case .rightShift: UInt16(kVK_RightShift)
        case .fn: UInt16(kVK_Function)
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .rightCommand: .command
        case .rightOption: .option
        case .rightControl: .control
        case .rightShift: .shift
        case .fn: .function
        }
    }

    var displayName: String {
        switch self {
        case .rightCommand: "Right \u{2318}"
        case .rightOption: "Right \u{2325}"
        case .rightControl: "Right \u{2303}"
        case .rightShift: "Right \u{21e7}"
        case .fn: "fn"
        }
    }

    /// Symbols shown as individual key caps in the hotkey recorder UI.
    var keySymbols: [String] {
        switch self {
        case .rightCommand: ["Right \u{2318}"]
        case .rightOption: ["Right \u{2325}"]
        case .rightControl: ["Right \u{2303}"]
        case .rightShift: ["Right \u{21e7}"]
        case .fn: ["fn"]
        }
    }

    static func from(keyCode: UInt16) -> HotkeyModifier? {
        allCases.first { $0.keyCode == keyCode }
    }
}
