import SwiftUI
import AppKit

/// Service responsible for managing and executing keyboard shortcuts across RiverFlow.
@MainActor
final class KeyboardShortcutHandler {
    static let shared = KeyboardShortcutHandler()
    private init() {}
    
    /// Checks whether the user is actively focused on an editable text input.
    static func isEditingText(in window: NSWindow? = nil) -> Bool {
        guard let responder = (window ?? NSApp.keyWindow)?.firstResponder else { return false }
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
        guard !viewModel.isJumpToPathPresented, !viewModel.isGitCommitPresented, viewModel.fileCollision == nil else { return false }
        let isEditing = Self.isEditingText() || viewModel.editingFileID != nil
        guard let action = KeyboardShortcutAction.allCases.first(where: { $0.matches(event: event) }) else {
            return false
        }
        if isEditing {
            switch action {
            case .delete, .permanentlyDelete, .openSelected:
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
        case .jumpToPath:
            viewModel.isJumpToPathPresented = true
            return true
        }
    }
}

/// The monitor belongs to one window and receives an updated model on every
/// active-pane change. Inactive windows must never consume another window's keys.
private struct KeyboardShortcutEventView: NSViewRepresentable {
    let viewModel: FolderViewModel
    let openWindow: (() -> Void)?

    func makeNSView(context: Context) -> EventView { EventView() }
    func updateNSView(_ view: EventView, context: Context) {
        view.handleEvent = { event in
            KeyboardShortcutHandler.shared.handleKeyEvent(event, viewModel: viewModel, openWindow: openWindow)
        }
    }

    final class EventView: NSView {
        var handleEvent: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window,
                      window.isKeyWindow, event.window === window else { return event }
                return self.handleEvent?(event) == true ? nil : event
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}

extension View {
    func handleKeyboardShortcuts(viewModel: FolderViewModel, openWindow: (() -> Void)? = nil) -> some View {
        background(KeyboardShortcutEventView(viewModel: viewModel, openWindow: openWindow))
    }
}
