import AppKit
import Testing
@testable import RiverFlow

@MainActor
@Suite struct FileCustomIconTests {
    @Test("Symbols are rendered as colored, non-template icons at multiple resolutions")
    func symbolRendering() throws {
        let image = try #require(FileCustomIconService.symbolIcon(named: "star.fill", color: .systemBlue))
        #expect(!image.isTemplate)
        #expect(image.representations.count == 7)
        let bitmap = try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first { $0.pixelsWide == 512 })
        let center = try #require(bitmap.colorAt(x: 256, y: 256)?.usingColorSpace(.deviceRGB))
        #expect(center.alphaComponent > 0.9)
        #expect(center.blueComponent > center.redComponent)
        #expect(FileCustomIconService.symbolIcon(named: "riverflow.invalid.symbol.name", color: .systemBlue) == nil)
    }

    @Test("Custom icons persist on files and folders and can be restored")
    func applyAndRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("sample.txt")
        try Data("sample".utf8).write(to: file)
        let folder = directory.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let icon = try #require(FileCustomIconService.symbolIcon(named: "star.fill", color: .systemBlue))
        for url in [file, folder] {
            #expect(!FileCustomIconService.hasCustomIcon(at: url))
            try FileCustomIconService.apply(icon, to: url)
            #expect(FileCustomIconService.hasCustomIcon(at: url))
            try FileCustomIconService.apply(nil, to: url)
            #expect(!FileCustomIconService.hasCustomIcon(at: url))
        }
        #expect(try Data(contentsOf: file) == Data("sample".utf8))
    }

    @Test("Changing a symbolic link cannot silently change its target")
    func symbolicLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("target")
        try Data("sample".utf8).write(to: target)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: FileCustomIconService.IconError.self) {
            try FileCustomIconService.apply(nil, to: link)
        }
        #expect(!FileCustomIconService.hasCustomIcon(at: target))
    }
}
