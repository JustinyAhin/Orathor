import Carbon.HIToolbox
import AppKit

enum HotkeyModifier: String, CaseIterable, Identifiable, Codable {
    case leftCommand = "leftCommand"
    case leftOption = "leftOption"
    case leftControl = "leftControl"
    case leftShift = "leftShift"
    case rightCommand = "rightCommand"
    case rightOption = "rightOption"
    case rightControl = "rightControl"
    case rightShift = "rightShift"
    case fn = "fn"

    var id: String { rawValue }

    var keyCode: UInt16 {
        switch self {
        case .leftCommand: UInt16(kVK_Command)
        case .leftOption: UInt16(kVK_Option)
        case .leftControl: UInt16(kVK_Control)
        case .leftShift: UInt16(kVK_Shift)
        case .rightCommand: UInt16(kVK_RightCommand)
        case .rightOption: UInt16(kVK_RightOption)
        case .rightControl: UInt16(kVK_RightControl)
        case .rightShift: UInt16(kVK_RightShift)
        case .fn: UInt16(kVK_Function)
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .leftCommand, .rightCommand: .command
        case .leftOption, .rightOption: .option
        case .leftControl, .rightControl: .control
        case .leftShift, .rightShift: .shift
        case .fn: .function
        }
    }

    var displayName: String {
        switch self {
        case .leftCommand: "Left \u{2318}"
        case .leftOption: "Left \u{2325}"
        case .leftControl: "Left \u{2303}"
        case .leftShift: "Left \u{21e7}"
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
        case .leftCommand: ["Left \u{2318}"]
        case .leftOption: ["Left \u{2325}"]
        case .leftControl: ["Left \u{2303}"]
        case .leftShift: ["Left \u{21e7}"]
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
