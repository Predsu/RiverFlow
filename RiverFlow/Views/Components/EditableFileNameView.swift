import SwiftUI

/// SwiftUI displaying editable, inline `FileItem` name.
struct EditableFileNameView: View {
    let file: FileItem
    let isEditing: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $editedName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        commitChange()
                    }
                    .onExitCommand {
                        onCancel()
                    }
                    .onAppear {
                        editedName = file.url.lastPathComponent
                        isFocused = true
                    }
            } else {
                Text(file.url.lastPathComponent)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }
    
    /// Commits file name change if it differs from old name.
    private func commitChange() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != file.url.lastPathComponent {
            onCommit(trimmed)
        } else {
            onCancel()
        }
    }
}
