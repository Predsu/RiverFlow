import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct GitCommitTests {
    private static func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_dir_" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        return tempDir
    }
    
    private static func createGitRepo() throws -> URL {
        let tempDir = try createTempDir()
        
        func runGit(_ args: [String]) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["git"] + args
            process.currentDirectoryURL = tempDir
            try? process.run()
            process.waitUntilExit()
        }
        
        runGit(["init"])
        runGit(["config", "user.name", "RiverFlow Tester"])
        runGit(["config", "user.email", "test@riverflow.app"])
        return tempDir
    }
    
    private static func deleteTempDir(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    @Test("GitCommitOptions default values")
    func gitCommitOptionsDefaultValues() {
        let options = GitCommitOptions()
        #expect(options.action == .commit)
        #expect(options.isAmend == false)
        #expect(options.isSignOff == false)
        #expect(options.isNoVerify == false)
        #expect(options.stageAll == false)
    }
    
    @Test("GitCommitOptions buildCommitArguments builds correct CLI arguments")
    func gitCommitOptionsBuildCommitArguments() {
        let basic = GitCommitOptions()
        #expect(basic.buildCommitArguments(message: "Initial commit") == ["commit", "-m", "Initial commit"])
        
        let amend = GitCommitOptions(isAmend: true)
        #expect(amend.buildCommitArguments(message: "Amended commit") == ["commit", "--amend", "-m", "Amended commit"])
        
        let signoff = GitCommitOptions(isSignOff: true)
        #expect(signoff.buildCommitArguments(message: "Signed commit") == ["commit", "--signoff", "-m", "Signed commit"])
        
        let noVerify = GitCommitOptions(isNoVerify: true)
        #expect(noVerify.buildCommitArguments(message: "No verify commit") == ["commit", "--no-verify", "-m", "No verify commit"])
        
        let stageAll = GitCommitOptions(stageAll: true)
        #expect(stageAll.buildCommitArguments(message: "Stage all commit") == ["commit", "-a", "-m", "Stage all commit"])
        
        let allOptions = GitCommitOptions(
            action: .commit,
            isAmend: true,
            isSignOff: true,
            isNoVerify: true,
            stageAll: true
        )
        #expect(allOptions.buildCommitArguments(message: "All options") == [
            "commit", "--amend", "--signoff", "--no-verify", "-a", "-m", "All options"
        ])
        
        let emptyAmend = GitCommitOptions(isAmend: true)
        #expect(emptyAmend.buildCommitArguments(message: "   ") == ["commit", "--amend"])
    }
    
    @Test("GitCommitAction cases expose icons and descriptions")
    func gitCommitActionCases() {
        #expect(GitCommitAction.allCases.count == 3)
        
        let commit = GitCommitAction.commit
        #expect(commit.id == "Commit")
        #expect(commit.iconName == "checkmark")
        #expect(!commit.description.isEmpty)
        
        let push = GitCommitAction.commitAndPush
        #expect(push.id == "Commit & Push")
        #expect(push.iconName == "arrow.up")
        #expect(!push.description.isEmpty)
        
        let sync = GitCommitAction.commitAndSync
        #expect(sync.id == "Commit & Sync")
        #expect(sync.iconName == "arrow.triangle.2.circlepath")
        #expect(!sync.description.isEmpty)
    }
    
    @Test("GitStatusSummary tracks counts and provides correct boolean flags")
    func gitStatusSummaryTracking() {
        let empty = GitStatusSummary()
        #expect(empty.totalChangesCount == 0)
        #expect(!empty.hasStagedChanges)
        #expect(!empty.hasUnstagedChanges)
        
        let withChanges = GitStatusSummary(
            stagedCount: 2,
            unstagedCount: 1,
            untrackedCount: 3,
            stagedFiles: [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")],
            unstagedFiles: [URL(fileURLWithPath: "/tmp/c.txt")]
        )
        #expect(withChanges.totalChangesCount == 6)
        #expect(withChanges.hasStagedChanges)
        #expect(withChanges.hasUnstagedChanges)
        #expect(withChanges.stagedFiles.count == 2)
        #expect(withChanges.unstagedFiles.count == 1)
    }
    
    @Test("FolderViewModel performGitCommit validates empty message and non-git directories")
    func folderViewModelPerformGitCommitValidations() async throws {
        let repoDir = try Self.createGitRepo()
        let nonGitDir = try Self.createTempDir()
        defer {
            Self.deleteTempDir(at: repoDir)
            Self.deleteTempDir(at: nonGitDir)
        }
        
        let viewModel = FolderViewModel(startDir: repoDir)
        
        let emptyResult: Result<String, Error> = await withCheckedContinuation { continuation in
            viewModel.performGitCommit(
                message: "   ",
                options: GitCommitOptions(),
                in: repoDir
            ) { continuation.resume(returning: $0) }
        }
        
        switch emptyResult {
        case .success:
            Issue.record("Expected empty commit message to fail")
        case .failure(let error):
            #expect((error as? GitError) == .emptyMessage)
        }
        
        let nonGitResult: Result<String, Error> = await withCheckedContinuation { continuation in
            viewModel.performGitCommit(
                message: "test",
                options: GitCommitOptions(),
                in: nonGitDir
            ) { continuation.resume(returning: $0) }
        }
        
        switch nonGitResult {
        case .success:
            Issue.record("Expected non-git directory commit to fail")
        case .failure(let error):
            #expect(error is GitError)
        }
    }
    
    @Test("GitCommitModalView and FolderContextMenu instantiate correctly")
    @MainActor
    func gitCommitModalViewAndContextMenuInstantiation() {
        let viewModel = FolderViewModel(startDir: URL(fileURLWithPath: "/tmp"))
        viewModel.isGitRepo = true
        
        var isPresented = true
        let modal = GitCommitModalView(
            viewModel: viewModel,
            isPresented: Binding(get: { isPresented }, set: { isPresented = $0 })
        )
        _ = modal.body
        
        let contextMenu = FolderContextMenu(viewModel: viewModel)
        _ = contextMenu.body
        
        #expect(modal != nil)
        #expect(contextMenu != nil)
    }
}