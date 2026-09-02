import SwiftUI
import AppKit

/// Category by which keyboard shortcuts are organized in macOS app menu bar.
enum ShortcutCategory: String, CaseIterable, Identifiable, Sendable {
    case fileOperations = "File Operations"
    case navigation = "Navigation"
    case window = "Window"
    
    var id: String { rawValue }
}

/// Enumeration of all supported keyboard shortcuts.
enum KeyboardShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case newFolder
    case newFile
    case delete
    case permanentlyDelete
    case openSelected
    case navigateUp
    case goBack
    case goForward
    case newWindow
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .newFolder: return "New Folder"
        case .newFile: return "New File"
        case .delete: return "Move to Trash"
        case .permanentlyDelete: return "Delete Immediately"
        case .openSelected: return "Open Selected"
        case .navigateUp: return "Enclosing Folder"
        case .goBack: return "Back"
        case .goForward: return "Forward"
        case .newWindow: return "New Window"
        }
    }
    
    var iconName: String {
        switch self {
        case .newFolder: return "folder.badge.plus"
        case .newFile: return "doc.badge.plus"
        case .delete: return "trash"
        case .permanentlyDelete: return "trash.slash"
        case .openSelected: return "arrow.up.forward.square"
        case .navigateUp: return "arrow.up"
        case .goBack: return "chevron.left"
        case .goForward: return "chevron.right"
        case .newWindow: return "macwindow.badge.plus"
        }
    }
    
    var category: ShortcutCategory {
        switch self {
        case .newFolder, .newFile, .delete, .permanentlyDelete, .openSelected:
            return .fileOperations
        case .navigateUp, .goBack, .goForward:
            return .navigation
        case .newWindow:
            return .window
        }
    }
    
    var keyCombo: KeyCombo {
        switch self {
        case .newFolder:
            return KeyCombo(key: "N", character: "n", modifiers: [.command, .shift], keyCode: 45)
        case .newFile:
            return KeyCombo(key: "n", character: "n", modifiers: [.command], keyCode: 45)
        case .delete:
            return KeyCombo(key: .delete, character: "\u{7f}", modifiers: [], keyCode: 51)
        case .permanentlyDelete:
            return KeyCombo(key: .delete, character: "\u{7f}", modifiers: [.command], keyCode: 51)
        case .openSelected:
            return KeyCombo(key: .return, character: "\r", modifiers: [], keyCode: 36)
        case .navigateUp:
            return KeyCombo(key: .upArrow, character: "", modifiers: [.command], keyCode: 126)
        case .goBack:
            return KeyCombo(key: "[", character: "[", modifiers: [.command], keyCode: 33)
        case .goForward:
            return KeyCombo(key: "]", character: "]", modifiers: [.command], keyCode: 30)
        case .newWindow:
            return KeyCombo(key: "t", character: "t", modifiers: [.command], keyCode: 17)
        }
    }
    
    var displayShortcut: String {
        switch self {
        case .newFolder: return "⇧⌘N"
        case .newFile: return "⌘N"
        case .delete: return "⌫"
        case .permanentlyDelete: return "⌘⌫"
        case .openSelected: return "↩"
        case .navigateUp: return "⌘↑"
        case .goBack: return "⌘["
        case .goForward: return "⌘]"
        case .newWindow: return "⌘T"
        }
    }
    
    /// Matches an AppKit NSEvent against this shortcut definition.
    func matches(event: NSEvent) -> Bool {
        let eventModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let combo = self.keyCombo
        
        var expectedFlags: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.command) { expectedFlags.insert(.command) }
        if combo.modifiers.contains(.shift) { expectedFlags.insert(.shift) }
        if combo.modifiers.contains(.option) { expectedFlags.insert(.option) }
        if combo.modifiers.contains(.control) { expectedFlags.insert(.control) }
        
        guard eventModifiers == expectedFlags else {
            return false
        }
        
        if let targetKeyCode = combo.keyCode, event.keyCode == targetKeyCode {
            return true
        }
        
        if let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
            if chars == combo.character.lowercased() {
                return true
            }
        }
        
        if self == .openSelected && (event.keyCode == 36 || event.keyCode == 76) {
            return true
        }
        
        if (self == .delete || self == .permanentlyDelete) && (event.keyCode == 51 || event.keyCode == 117) {
            return true
        }
        
        return false
    }
}


/// Key combination for a shortcut action.
struct KeyCombo: Sendable, Equatable {
    let key: KeyEquivalent
    let character: String
    let modifiers: EventModifiers
    let keyCode: UInt16?
    
    init(key: KeyEquivalent, character: String, modifiers: EventModifiers = [], keyCode: UInt16? = nil) {
        self.key = key
        self.character = character
        self.modifiers = modifiers
        self.keyCode = keyCode
    }
}
