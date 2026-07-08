import SwiftUI
import AppKit

struct FileIconView: View {
    let file: FileItem
    var baseSize: CGFloat = 64
    
    var body: some View {
        if file.itemType == .DIRECTORY {
            Image(systemName: "folder")
                .font(.system(size: baseSize))
                .foregroundColor(.blue)
        } else {
            ZStack(alignment: .bottom) {
                Image(systemName: "doc")
                    .font(.system(size: baseSize))
                    .foregroundColor(.secondary)
                
                if !file.fileExtensionIconText.isEmpty {
                    Text(file.fileExtensionIconText)
                        .font(.system(size: baseSize * 0.18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .padding(.bottom, baseSize * 0.22)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

struct FileGridItemView: View {
    let file: FileItem
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            FileIconView(file: file, baseSize: 48) // lekko odchudzona ikona dla zbalansowania paddingu ramki
            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(alignment: .top)
        }
        .padding(10)
        .frame(width: 120, height: 110)
        // Nadawanie koloru tła selekcji wewnątrz zaokrąglonego kafelka
        .background(isSelected ? Color(.selectedControlColor).opacity(0.15) : Color.clear)
        .cornerRadius(8)
        // Dynamiczny outline (grubość linii 2px, gdy element jest wybrany)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.selectedControlColor), lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
        // Naprawiony gest symultaniczny: nie blokuje wątku wejścia przy szybkim klikaniu
        .gesture(
            TapGesture(count: 1)
                .onEnded {
                    onTap()
                }
                .simultaneously(
                    with: TapGesture(count: 2)
                        .onEnded {
                            onDoubleTap()
                        }
                )
        )
        .contextMenu {
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }) {
                Text("Copy Full Path")
                Image(systemName: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                } catch {
                    print("Error while moving item to trash \(error.localizedDescription)")
                }
            }) {
                Text("Move to Trash")
                Image(systemName: "trash")
            }
            
            Divider()
        }
    }
}

struct InteractivePathTitleView: View {
    let fullPath: String
    let folderName: String
    
    @State private var isHoveringPath = false
    @State private var showCopyFeedback = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isHoveringPath {
                Text(fullPath)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    // Płynne wejście/wyjście samej ścieżki
                    .transition(.asymmetric(insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                                            removal: .identity))
            } else {
                Text(folderName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .transition(.identity)
            }
            
            if isHoveringPath {
                Image(systemName: showCopyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(showCopyFeedback ? .green : .secondary)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(isHoveringPath ? Color(NSColor.quaternaryLabelColor) : Color.clear)
        .cornerRadius(4)
        .frame(minWidth: 140, maxWidth: 320, alignment: .leading)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHoveringPath)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHoveringPath = hovering
            }
        }
        .onTapGesture {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(fullPath, forType: .string)
            
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopyFeedback = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showCopyFeedback = false
                }
            }
        }
    }
}
