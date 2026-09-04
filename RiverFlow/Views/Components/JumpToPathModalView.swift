import SwiftUI
import AppKit

/// SwiftUI modal view for jumping to a directory path with smart autocompletion.
struct JumpToPathModalView: View {
    let viewModel: FolderViewModel
    @Binding var isPresented: Bool
    
    @State private var pathInput: String = "~/"
    @State private var suggestions: [PathSuggestion] = []
    @State private var selectedSuggestionIndex: Int = 0
    @State private var errorMessage: String? = nil
    @FocusState private var isFieldFocused: Bool
    
    private let autocompleteService = PathAutocompleteService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                TextField("Enter directory name", text: $pathInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .focused($isFieldFocused)
                    .onSubmit {
                        submitCurrentSelection()
                    }
                    .onChange(of: pathInput) { _, newValue in
                        updateSuggestions(for: newValue)
                    }
                
                if !pathInput.isEmpty {
                    Button(action: {
                        pathInput = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }
            
            if !suggestions.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                                suggestionRow(suggestion, isSelected: index == selectedSuggestionIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSuggestionIndex = index
                                        selectSuggestion(suggestion)
                                    }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 240)
                    .onChange(of: selectedSuggestionIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else if !pathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .center, spacing: 6) {
                    Text("No matching folders found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("If you can't find your folder despite its existence try getting through the parent folders first.")
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.8))
                    Text("This is an indexing mechanism allowing the search to run fast.")
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            }
            
            Divider()
            
            HStack {
                HStack(spacing: 12) {
                    keyHint(key: "⇥ Tab", label: "Completion")
                    keyHint(key: "↑/↓", label: "Select")
                    keyHint(key: "↩ Return", label: "Go")
                    keyHint(key: "⎋ Esc", label: "Exit")
                }
                
                Spacer()
                
                Button("Exit") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Go") {
                    submitCurrentSelection()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 520)
        .background(Material.regular)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
        .onAppear {
            isFieldFocused = true
            updateSuggestions(for: pathInput)
        }
        .onKeyPress(.downArrow) {
            if !suggestions.isEmpty {
                selectedSuggestionIndex = (selectedSuggestionIndex + 1) % suggestions.count
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if !suggestions.isEmpty {
                selectedSuggestionIndex = (selectedSuggestionIndex - 1 + suggestions.count) % suggestions.count
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.tab) {
            if !suggestions.isEmpty && selectedSuggestionIndex >= 0 && selectedSuggestionIndex < suggestions.count {
                let selected = suggestions[selectedSuggestionIndex]
                pathInput = selected.relativeDisplayPath + "/"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
    
    private func suggestionRow(_ suggestion: PathSuggestion, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconForSuggestion(suggestion))
                .foregroundColor(isSelected ? .white : .accentColor)
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(suggestion.relativeDisplayPath)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
    
    private func keyHint(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.quaternaryLabelColor))
                .cornerRadius(3)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private func iconForSuggestion(_ suggestion: PathSuggestion) -> String {
        let name = suggestion.displayName.lowercased()
        switch name {
        case "desktop": return "menubar.dock.rectangle"
        case "documents": return "doc.text.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "pictures": return "photo.on.rectangle.angled"
        case "movies": return "film"
        case "music": return "music.note"
        default: return "folder.fill"
        }
    }
    
    private func updateSuggestions(for query: String) {
        errorMessage = nil
        let newSuggestions = autocompleteService.autocompletionSuggestions(
            for: query,
            currentDir: viewModel.currentDir
        )
        self.suggestions = newSuggestions
        self.selectedSuggestionIndex = 0
    }
    
    private func selectSuggestion(_ suggestion: PathSuggestion) {
        viewModel.navigateTo(url: suggestion.url)
        isPresented = false
    }
    
    private func submitCurrentSelection() {
        if !suggestions.isEmpty && selectedSuggestionIndex >= 0 && selectedSuggestionIndex < suggestions.count {
            let selected = suggestions[selectedSuggestionIndex]
            if pathInput.trimmingCharacters(in: .whitespacesAndNewlines) != selected.relativeDisplayPath {
                selectSuggestion(selected)
                return
            }
        }
        
        let path = pathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if viewModel.jumpTo(path: path) {
            isPresented = false
        } else {
            errorMessage = "Folder \"\(path)\" could not be found or opened."
        }
    }
}
