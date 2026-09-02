import SwiftUI
import AppKit

/// Service responsible for managing and executing keyboard shortcuts across RiverFlow.
@MainActor
final class KeyboardShortcutHandler {
    static let shared = KeyboardShortcutHandler()
    private init() {}
    
    /// Checks whether the user is actively focused on an editable text input.
    static func isEditingText(in window: NSWindow? = NSApp.keyWindow) -> Bool {
        guard let responder = window?.firstResponder else { return false }
        if responder is NSTextField { return true }
        if let textView = responder as? NSTextView {
            return textView.isEditable
        }
        return false
    }
    
    /// Handles an NSEvent by matching against known keyboard shortcuts.
    /// - Returns: `true` if the event was consumed and handled, `false` otherwise.
    @discardableResult
    func handleKeyEvent(
        _ event: NSEvent,
        viewModel: FolderViewModel,
        openWindow: (() -> Void)? = nil
    ) -> Bool {
        let isEditing = Self.isEditingText() || viewModel.editingFileID != nil
        guard let action = KeyboardShortcutAction.allCases.first(where: { $0.matches(event: event) }) else {
            return false
        }
        if isEditing {
            switch action {
            case .delete, .openSelected:
                return false
            default:
                break
            }
        }
        return execute(action: action, viewModel: viewModel, openWindow: openWindow)
    }
    
    /// Executes a specific keyboard shortcut action.
    @discardableResult
    func execute(
        action: KeyboardShortcutAction,
        viewModel: FolderViewModel,
        openWindow: (() -> Void)? = nil
    ) -> Bool {
        switch action {
        case .newFolder:
            viewModel.createNewDirectory()
            return true
        case .newFile:
            viewModel.createNewFile()
            return true
        case .delete:
            if !viewModel.selectedFiles.isEmpty {
                viewModel.moveSelectedToTrash()
                return true
            }
            return false
        case .permanentlyDelete:
            if !viewModel.selectedFiles.isEmpty {
                viewModel.permanentlyDeleteSelected()
                return true
            }
            return false
        case .openSelected:
            if !viewModel.selectedFiles.isEmpty {
                viewModel.openSelectedFiles()
                return true
            }
            return false
        case .navigateUp:
            if viewModel.currentDir.path != "/" {
                viewModel.goToParentDirectory()
                return true
            }
            return false
        case .goBack:
            if !viewModel.historyBackward.isEmpty {
                viewModel.goBackward()
                return true
            }
            return false
        case .goForward:
            if !viewModel.historyForward.isEmpty {
                viewModel.goForward()
                return true
            }
            return false
        case .newWindow:
            if let openWindow = openWindow {
                openWindow()
            } else {
                NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
            }
            return true
        }
    }
}

/// SwiftUI ViewModifier that attaches keyboard shortcut handling to any view.
struct KeyboardShortcutModifier: ViewModifier {
    let viewModel: FolderViewModel
    var openWindow: (() -> Void)?
    
    @State private var eventMonitor: Any?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                setupMonitor()
            }
            .onDisappear {
                removeMonitor()
            }
    }
    
    private func setupMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if KeyboardShortcutHandler.shared.handleKeyEvent(event, viewModel: viewModel, openWindow: openWindow) {
                return nil
            }
            return event
        }
    }
    
    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

extension View {
    /// Enables keyboard shortcuts on this view hierarchy.
    func handleKeyboardShortcuts(viewModel: FolderViewModel, openWindow: (() -> Void)? = nil) -> some View {
        self.modifier(KeyboardShortcutModifier(viewModel: viewModel, openWindow: openWindow))
    }
}
