import Foundation
import Testing
@testable import RiverFlow

@Suite struct FilePreviewTests {
    @Test("Preview follows visible selection and clears when filtering it out")
    func previewFollowsVisibleSelectionAndClearsWhenFilteringItOut() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("Hello".utf8).write(to: directory.appendingPathComponent("hello.txt"))
        try Data("Other".utf8).write(to: directory.appendingPathComponent("other.txt"))
        let model = FolderViewModel(startDir: directory)
        let hello = try #require(model.files.first { $0.name == "hello.txt" })
        #expect(model.previewFiles.isEmpty)
        model.selectedFileIds = [hello.id]
        #expect(model.previewFiles.map(\.url) == [hello.url])
        model.searchText = "other"
        #expect(model.previewFiles.isEmpty)
        model.searchText = ""
        model.selectedFileIds = Set(model.files.map(\.id))
        #expect(model.previewFiles.count == 2)
        model.selectedFileIds = []
        #expect(model.previewFiles.isEmpty)
    }

    @Test("Preview resolves selected Spotlight results outside the current folder")
    func previewResolvesSelectedSpotlightResultsOutsideTheCurrentFolder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = FolderViewModel(startDir: directory)
        model.searchScope = .thisMac
        model.searchText = "report"
        let result = FileItem(url: directory.appendingPathComponent("report.pdf"), name: "report.pdf", itemType: .FILE, size: 42, modificationDate: nil, isHidden: false)
        model.globalSearchResults = [result]
        model.selectedFileIds = [result.id]
        #expect(model.previewFiles.map(\.url) == [result.url])
        model.searchText = ""
        #expect(model.previewFiles.isEmpty)
    }
}
