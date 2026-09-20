import SwiftUI
import AppKit

/// SwiftUI modal window for Git commit operations, styled after VSCode Source Control.
struct GitCommitModalView: View {
    let viewModel: FolderViewModel
    @Binding var isPresented: Bool
    
    @State private var commitMessage: String = ""
    @State private var commitOptions: GitCommitOptions = GitCommitOptions()
    @State private var statusSummary: GitStatusSummary = GitStatusSummary()
    @State private var isCommitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showOptionsDetails: Bool = true
    @FocusState private var isMessageEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if let error = errorMessage {
                errorBanner(message: error)
                Divider()
            }
            
            changesSummaryBar
            
            Divider()
            
            messageEditorSection
            
            Divider()
            
            commitOptionsSection
            
            Divider()
            
            footerView
        }
        .frame(width: 540)
        .background(Material.regular)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
        .onAppear {
            refreshSummary()
            isMessageEditorFocused = true
            if statusSummary.stagedCount == 0 && statusSummary.hasUnstagedChanges {
                commitOptions.stageAll = true
            }
        }
        .onKeyPress(.escape) {
            if !isCommitting {
                isPresented = false
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Git Commit")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let branch = viewModel.gitBranch {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                            Text(branch)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                    }
                }
                
                Text(viewModel.currentDir.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Button(action: {
                if !isCommitting {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isCommitting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Changes Summary Bar
    
    private var changesSummaryBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(statusSummary.hasStagedChanges ? .green : .secondary)
                    .font(.caption)
                Text("\(statusSummary.stagedCount) Staged")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusSummary.hasStagedChanges ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusSummary.hasStagedChanges ? Color.green.opacity(0.12) : Color.clear)
            .cornerRadius(5)
            
            HStack(spacing: 6) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(statusSummary.hasUnstagedChanges ? .orange : .secondary)
                    .font(.caption)
                Text("\(statusSummary.unstagedCount + statusSummary.untrackedCount) Unstaged")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusSummary.hasUnstagedChanges ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusSummary.hasUnstagedChanges ? Color.orange.opacity(0.12) : Color.clear)
            .cornerRadius(5)
            
            Spacer()
            
            if !statusSummary.hasStagedChanges && statusSummary.hasUnstagedChanges {
                Text(commitOptions.stageAll ? "All changes will be staged" : "No changes staged")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Message Editor Section
    
    private var messageEditorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if commitMessage.isEmpty {
                    Text("Message (⌘⏎ to commit)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: $commitMessage)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(height: 90)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .focused($isMessageEditorFocused)
                    .disabled(isCommitting)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isMessageEditorFocused ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
            )
            
            HStack {
                let charCount = commitMessage.count
                let firstLineCount = commitMessage.components(separatedBy: .newlines).first?.count ?? 0
                
                Text("Subject: \(firstLineCount)/50 chars")
                    .font(.caption2)
                    .foregroundColor(firstLineCount > 50 ? .orange : .secondary)
                
                if charCount > firstLineCount {
                    Text("• Total: \(charCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if commitOptions.isAmend {
                    Button("Load Previous Commit Message") {
                        if let lastMsg = viewModel.getLastCommitMessage() {
                            commitMessage = lastMsg
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Commit Options Section (VSCode Style)
    
    private var commitOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COMMIT OPTIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOptionsDetails.toggle()
                    }
                }) {
                    Image(systemName: showOptionsDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if showOptionsDetails {
                VStack(spacing: 6) {
                    optionToggle(
                        title: "Amend previous commit",
                        subtitle: "Amend the last commit instead of creating a new one (--amend)",
                        isOn: $commitOptions.isAmend
                    )
                    .onChange(of: commitOptions.isAmend) { _, isAmend in
                        if isAmend && commitMessage.isEmpty {
                            if let lastMsg = viewModel.getLastCommitMessage() {
                                commitMessage = lastMsg
                            }
                        }
                    }
                    
                    optionToggle(
                        title: "Sign-off commit",
                        subtitle: "Add Signed-off-by trailer at the end of the commit message (--signoff)",
                        isOn: $commitOptions.isSignOff
                    )
                    
                    optionToggle(
                        title: "No verify (Skip hooks)",
                        subtitle: "Bypass pre-commit and commit-msg git hooks (--no-verify)",
                        isOn: $commitOptions.isNoVerify
                    )
                    
                    optionToggle(
                        title: "Stage all changes",
                        subtitle: "Automatically stage all modified and untracked files (-a / git add -A)",
                        isOn: $commitOptions.stageAll
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
    
    private func optionToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(isCommitting)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                keyHint(key: "⌘ ↩", label: commitOptions.action.rawValue)
                keyHint(key: "⎋", label: "Cancel")
            }
            
            Spacer()
            
            if isCommitting {
                ProgressView()
                    .controlSize(.small)
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isCommitting)
            
            commitSplitButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var commitSplitButton: some View {
        HStack(spacing: 1) {
            Button(action: executeCommit) {
                HStack(spacing: 5) {
                    Image(systemName: commitOptions.action.iconName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(commitOptions.action.rawValue)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCommitting || (commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !commitOptions.isAmend))
            .keyboardShortcut(.return, modifiers: [.command])
            
            Menu {
                ForEach(GitCommitAction.allCases) { action in
                    Button(action: {
                        commitOptions.action = action
                    }) {
                        HStack {
                            Image(systemName: action.iconName)
                            Text(action.rawValue)
                            if commitOptions.action == action {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 2)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(isCommitting)
        }
    }
    
    private var progressText: String {
        switch commitOptions.action {
        case .commit:
            return "Committing..."
        case .commitAndPush:
            return "Committing & pushing..."
        case .commitAndSync:
            return "Committing & syncing..."
        }
    }
    
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(4)
            
            Spacer()
            
            Button(action: {
                errorMessage = nil
            }) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
    }
    
    private func keyHint(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.quaternaryLabelColor))
                .cornerRadius(3)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Operations
    
    private func refreshSummary() {
        statusSummary = viewModel.getGitStatusSummary()
    }
    
    private func executeCommit() {
        errorMessage = nil
        let trimmedMsg = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !commitOptions.isAmend && trimmedMsg.isEmpty {
            errorMessage = "Commit message cannot be empty."
            return
        }
        
        isCommitting = true
        viewModel.performGitCommit(message: trimmedMsg, options: commitOptions) { result in
            isCommitting = false
            switch result {
            case .success:
                isPresented = false
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
