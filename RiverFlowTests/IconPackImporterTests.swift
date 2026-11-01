import AppKit
import Testing
@testable import RiverFlow

@MainActor
@Suite struct IconPackImporterTests {
    private let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 16\"><path fill=\"#1a9fff\" d=\"M0 0h16v16H0z\"/></svg>"

    private func fixture(license: Bool = true) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("icons"), withIntermediateDirectories: true)
        try Data(svg.utf8).write(to: root.appendingPathComponent("icons/sample.svg"))
        try Data(svg.utf8).write(to: root.appendingPathComponent("icons/folder-sample.svg"))
        if license { try Data("MIT\nCopyright Test Authors\nPermission is hereby granted".utf8).write(to: root.appendingPathComponent("LICENSE")) }
        try Data("{\"displayName\":\"Example Pack\",\"version\":\"1.0\",\"repository\":{\"url\":\"https://example.com/icons.git\"}}".utf8).write(to: root.appendingPathComponent("package.json"))
        return root
    }

    @Test("Folder imports preserve source and licenses, persist SVG icons, replace and remove packs")
    func folderImportsPreserveSourceAndLicensesPersistSVGIconsReplaceAndRemovePacks() throws {
        let folder = try fixture()
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder); try? FileManager.default.removeItem(at: storage) }
        let prepared = try IconPackImporter.prepare(folder)
        defer { prepared.discard() }
        #expect(prepared.pack.name == "Example Pack")
        #expect(prepared.pack.icons.count == 2)
        #expect(prepared.pack.notices.contains("Copyright Test Authors"))
        #expect(prepared.pack.source == "https://example.com/icons")
        let store = ImportedIconPackStore(root: storage)
        try store.install(prepared)
        let reloaded = ImportedIconPackStore(root: storage)
        #expect(reloaded.pack?.id == prepared.pack.id)
        let icon = try #require(reloaded.pack?.icons.first)
        let image = try #require(reloaded.image(for: icon))
        #expect(image.isValid)
        #expect(!image.isTemplate)
        #expect(image.size == NSSize(width: 512, height: 512))
        let replacement = try IconPackImporter.prepare(folder)
        defer { replacement.discard() }
        try reloaded.install(replacement)
        #expect(reloaded.pack?.id == replacement.pack.id)
        #expect(!FileManager.default.fileExists(atPath: storage.appendingPathComponent(prepared.pack.id.uuidString).path))
        try reloaded.remove()
        #expect(ImportedIconPackStore(root: storage).pack == nil)
        #expect(!FileManager.default.fileExists(atPath: storage.appendingPathComponent(replacement.pack.id.uuidString).path))
    }

    @Test("Downloaded ZIPs and Safari's extracted parent folder are accepted")
    func downloadedZIPAndSafariExtractedParentFolderAreAccepted() throws {
        let folder = try fixture()
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let zip = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        defer {
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.removeItem(at: parent)
            try? FileManager.default.removeItem(at: zip)
        }
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: folder, to: parent.appendingPathComponent("material-icon-theme-main"))
        let fromParent = try IconPackImporter.prepare(parent)
        defer { fromParent.discard() }
        #expect(fromParent.pack.icons.count == 2)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", folder.path, zip.path]
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let fromZIP = try IconPackImporter.prepare(zip)
        defer { fromZIP.discard() }
        #expect(fromZIP.pack.icons.count == 2)
        #expect(fromZIP.pack.notices == fromParent.pack.notices)
    }

    @Test("ZIP path traversal is rejected before extraction")
    func ZIPPathTraversalIsRejectedBeforeExtraction() throws {
        let folder = try fixture()
        let zip = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        defer { try? FileManager.default.removeItem(at: folder); try? FileManager.default.removeItem(at: zip) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", folder.path, zip.path]
        try process.run(); process.waitUntilExit()
        try IconPackImporter.validateZIP(zip)
        var data = try Data(contentsOf: zip)
        let original = Data("sample.svg".utf8)
        let replacement = Data("../bad.svg".utf8)
        var offset = 0
        while let range = data.range(of: original, in: offset..<data.count) {
            data.replaceSubrange(range, with: replacement)
            offset = range.upperBound
        }
        try data.write(to: zip)
        #expect(throws: IconPackImportError.self) { try IconPackImporter.validateZIP(zip) }
    }

    @Test("Incomplete packs fail with instructions and cannot replace the active pack")
    func incompletePacksFailWithInstructionsAndCannotReplaceTheActivePack() throws {
        let folder = try fixture(license: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: IconPackImportError.self) { try IconPackImporter.prepare(folder) }
    }

    @Test("SVGs cannot load scripts, remote content, or XML entities")
    func SVGCannotLoadScriptsRemoteContentOrXMLEntities() throws {
        try IconPackImporter.validateSVG(Data(svg.utf8))
        for xml in [
            "<svg><script>alert(1)</script></svg>",
            "<svg><image href=\"https://example.com/tracker.png\"/></svg>",
            "<svg><path onclick=\"run()\"/></svg>",
            "<svg><path fill=\"url(https://example.com/image)\"/></svg>",
            "<!DOCTYPE svg [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><svg>&x;</svg>",
            "<svg><style><![CDATA[@import url(https://example.com/style);]]></style></svg>"
        ] {
            #expect(throws: IconPackImportError.self) { try IconPackImporter.validateSVG(Data(xml.utf8)) }
        }
    }

    @Test("Symlinks cannot import a file from outside the selected folder")
    func symlinksCannotImportFileFromOutsideTheSelectedFolder() throws {
        let folder = try fixture()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".svg")
        defer { try? FileManager.default.removeItem(at: folder); try? FileManager.default.removeItem(at: outside) }
        try Data(svg.utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("icons/outside.svg"), withDestinationURL: outside)
        let prepared = try IconPackImporter.prepare(folder)
        defer { prepared.discard() }
        #expect(prepared.pack.icons.count == 2)
        #expect(prepared.skipped == 1)
    }
}
