import Foundation

/// Defines the primary commit action variant, resembling VSCode Source Control's commit button.
public enum GitCommitAction: String, CaseIterable, Identifiable {
    case commit = "Commit"
    case commitAndPush = "Commit & Push"
    case commitAndSync = "Commit & Sync"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .commit:
            return "checkmark"
        case .commitAndPush:
            return "arrow.up"
        case .commitAndSync:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    public var description: String {
        switch self {
        case .commit:
            return "Commit changes to the local repository"
        case .commitAndPush:
            return "Commit changes and push to the remote branch"
        case .commitAndSync:
            return "Commit changes, pull remote changes with rebase, and push"
        }
    }
}

/// Options configured in the Git commit modal window.
public struct GitCommitOptions: Equatable {
    public var action: GitCommitAction
    public var isAmend: Bool
    public var isSignOff: Bool
    public var isNoVerify: Bool
    public var stageAll: Bool
    
    public init(
        action: GitCommitAction = .commit,
        isAmend: Bool = false,
        isSignOff: Bool = false,
        isNoVerify: Bool = false,
        stageAll: Bool = false
    ) {
        self.action = action
        self.isAmend = isAmend
        self.isSignOff = isSignOff
        self.isNoVerify = isNoVerify
        self.stageAll = stageAll
    }
    
    /// Constructs the git command arguments for the commit command.
    ///
    /// - Parameter message: The commit message string.
    /// - Returns: Array of CLI arguments passed to `git`.
    public func buildCommitArguments(message: String) -> [String] {
        var args = ["commit"]
        
        if isAmend {
            args.append("--amend")
        }
        
        if isSignOff {
            args.append("--signoff")
        }
        
        if isNoVerify {
            args.append("--no-verify")
        }
        
        if stageAll {
            args.append("-a")
        }
        
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMessage.isEmpty {
            args.append("-m")
            args.append(trimmedMessage)
        }
        
        return args
    }
}

/// Summary of git staging status for the current repository.
public struct GitStatusSummary: Equatable {
    public let stagedCount: Int
    public let unstagedCount: Int
    public let untrackedCount: Int
    public let stagedFiles: [URL]
    public let unstagedFiles: [URL]
    
    public init(
        stagedCount: Int = 0,
        unstagedCount: Int = 0,
        untrackedCount: Int = 0,
        stagedFiles: [URL] = [],
        unstagedFiles: [URL] = []
    ) {
        self.stagedCount = stagedCount
        self.unstagedCount = unstagedCount
        self.untrackedCount = untrackedCount
        self.stagedFiles = stagedFiles
        self.unstagedFiles = unstagedFiles
    }
    
    public var totalChangesCount: Int {
        stagedCount + unstagedCount + untrackedCount
    }
    
    public var hasStagedChanges: Bool {
        stagedCount > 0
    }
    
    public var hasUnstagedChanges: Bool {
        unstagedCount > 0 || untrackedCount > 0
    }
}
