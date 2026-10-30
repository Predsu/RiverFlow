import Foundation
import Testing
@testable import RiverFlow

@Suite struct FileInfoMetadataTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Inspector reads exact bytes and ownership mode without changing the file")
    func inspectorReadsExactBytesAndOwnershipModeWithoutChangingTheFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.txt")
        try Data("hello".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: url.path)
        let snapshot = try FileInfoMetadata.read(at: url)
        let fields = snapshot.general.flatMap(\.fields)
        #expect(fields.first { $0.label == "Exact size" }?.value == "5 bytes")
        let ownership = try #require(snapshot.permissions.first { $0.title == "Ownership" })
        #expect(ownership.fields.first { $0.label == "Mode" }?.value == "0640")
        let access = try #require(snapshot.permissions.first { $0.title == "POSIX permissions" })
        #expect(access.fields.map(\.value) == ["Read, Write", "Read", "No access"])
        #expect(try Data(contentsOf: url) == Data("hello".utf8))
    }

    @Test("Folder totals include hidden files and packages without traversing links")
    func folderTotalsIncludeHiddenFilesAndPackagesWithoutTraversingLinks() throws {
        let directory = try temporaryDirectory()
        let outside = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: outside)
        }
        try Data(repeating: 0, count: 1000).write(to: outside.appendingPathComponent("outside.bin"))
        try Data([1, 2, 3]).write(to: directory.appendingPathComponent(".hidden"))
        let package = directory.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data([1, 2]).write(to: package.appendingPathComponent("content"))
        let link = directory.appendingPathComponent("linked-folder")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let linkAttributes = try FileManager.default.attributesOfItem(atPath: link.path)
        let linkSize = try #require(linkAttributes[.size] as? NSNumber).int64Value
        let summary = FileInfoFolderSummary.read(at: directory)
        #expect(summary.files == 3)
        #expect(summary.folders == 1)
        #expect(summary.bytes == 5 + linkSize)
        #expect(summary.unreadableItems == 0)
        let snapshot = try FileInfoMetadata.read(at: link)
        #expect(snapshot.kind == "Symbolic link")
        #expect(snapshot.details.flatMap(\.fields).contains { $0.label == "Link target" && $0.value == outside.path })
    }

    @Test("Dangling symbolic links remain inspectable")
    func danglingSymbolicLinksRemainInspectable() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let link = directory.appendingPathComponent("broken-link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "missing-target")
        let snapshot = try FileInfoMetadata.read(at: link)
        #expect(snapshot.kind == "Symbolic link")
        #expect(snapshot.details.flatMap(\.fields).contains { $0.label == "Link target" && $0.value == "missing-target" })
    }

    @Test("Missing items report a read failure instead of fabricated zero sizes")
    func missingItemsReportReadFailureInsteadOfFabricatedZeroSizes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(throws: (any Error).self) { try FileInfoMetadata.read(at: url) }
    }
}
