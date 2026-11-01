import AppKit
import Foundation
import Combine

struct ImportedIconPack: Codable, Identifiable, Sendable {
    struct Icon: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let category: String
        let filename: String
        var displayName: String { id.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ") }
    }
    let id: UUID
    let name: String
    let version: String?
    let source: String?
    let notices: String
    let icons: [Icon]
}

struct PreparedIconPack: Sendable {
    let pack: ImportedIconPack
    let directory: URL
    let skipped: Int
    func discard() { try? FileManager.default.removeItem(at: directory) }
}

enum IconPackImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case let .invalid(message) = self { return message }
        return nil
    }
}

enum IconPackImporter {
    static let downloadURL = URL(string: "https://github.com/material-extensions/vscode-material-icon-theme/archive/refs/heads/main.zip")!
    static let projectURL = URL(string: "https://github.com/material-extensions/vscode-material-icon-theme")!
    static let maximumIcons = 3000
    private static let maximumFileSize = 2 * 1024 * 1024

    static func prepare(_ selection: URL) throws -> PreparedIconPack {
        let manager = FileManager.default
        let scratch = manager.temporaryDirectory.appendingPathComponent("RiverFlow-icon-import-" + UUID().uuidString)
        try manager.createDirectory(at: scratch, withIntermediateDirectories: true)
        var success = false
        defer { if !success { try? manager.removeItem(at: scratch) } }
        let selected = try selection.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard selected.isSymbolicLink != true else { throw invalid("Choose the downloaded ZIP or the original folder, not a shortcut.") }
        let source: URL
        if selected.isDirectory == true {
            source = selection
        } else {
            guard selection.pathExtension.lowercased() == "zip" else { throw invalid("Choose the downloaded ZIP or its extracted folder.") }
            try validateZIP(selection)
            let extracted = scratch.appendingPathComponent("unpacked")
            try manager.createDirectory(at: extracted, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", selection.path, extracted.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw invalid("This ZIP could not be opened. Try downloading it again or choose its extracted folder.") }
            source = extracted
        }
        let root = try findPackRoot(source)
        let rootItems = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        let licenseFiles = rootItems.filter {
            let name = $0.lastPathComponent.lowercased()
            return ["license", "licence", "copying", "notice"].contains($0.deletingPathExtension().lastPathComponent.lowercased())
                || ["license-material-icon-theme.txt", "thirdpartynotices.txt"].contains(name)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !licenseFiles.isEmpty else { throw invalid("No license file was found. Choose the complete downloaded pack, including its LICENSE file, instead of only the icons folder.") }
        let notices = try licenseFiles.map { url in "\(url.lastPathComponent)\n\n" + (try readText(url)) }.joined(separator: "\n\n———\n\n")
        let metadataURL = root.appendingPathComponent("package.json")
        var metadata: [String: Any] = [:]
        if manager.fileExists(atPath: metadataURL.path) {
            metadata = (try? JSONSerialization.jsonObject(with: Data(readText(metadataURL).utf8))) as? [String: Any] ?? [:]
        }
        let name = metadata["displayName"] as? String ?? "Imported Icon Pack"
        let version = metadata["version"] as? String
        let repository = (metadata["repository"] as? [String: Any])?["url"] as? String ?? metadata["repository"] as? String
        let sourceLink = repository.flatMap { value -> String? in
            let text = value.replacingOccurrences(of: "git+", with: "").replacingOccurrences(of: ".git", with: "")
            guard let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
            return text
        }
        let candidates = try manager.contentsOfDirectory(at: root.appendingPathComponent("icons"), includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            .filter { ["svg", "png", "pdf", "jpg", "jpeg", "tiff", "icns"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard candidates.count <= maximumIcons else { throw invalid("This pack has too many icons. Choose a pack with at most \(maximumIcons) icons.") }
        let output = scratch.appendingPathComponent("pack")
        let iconDirectory = output.appendingPathComponent("icons")
        try manager.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
        var icons: [ImportedIconPack.Icon] = []
        var used = Set<String>()
        var skipped = 0
        var totalBytes = 0
        for url in candidates {
            if Task.isCancelled { throw CancellationError() }
            let data: Data
            do {
                data = try readFile(url)
                if url.pathExtension.lowercased() == "svg" { try validateSVG(data) }
            } catch { skipped += 1; continue }
            totalBytes += data.count
            guard totalBytes <= 128 * 1024 * 1024 else { throw invalid("This pack contains too much image data. Choose a smaller pack.") }
            let identifier = url.deletingPathExtension().lastPathComponent
            guard !identifier.isEmpty, !identifier.hasPrefix("."), used.insert(identifier).inserted else { skipped += 1; continue }
            let filename = UUID().uuidString + "." + url.pathExtension.lowercased()
            try data.write(to: iconDirectory.appendingPathComponent(filename), options: .atomic)
            icons.append(.init(id: identifier, category: identifier.hasPrefix("folder-") ? "Folders" : "Files", filename: filename))
        }
        guard !icons.isEmpty else { throw invalid("No supported icons were found. Download the complete Material Icon Theme ZIP and choose it here.") }
        let pack = ImportedIconPack(id: UUID(), name: String(name.prefix(120)), version: version.map { String($0.prefix(50)) }, source: sourceLink, notices: notices, icons: icons)
        try JSONEncoder().encode(pack).write(to: output.appendingPathComponent("pack.json"), options: .atomic)
        // Preserve the original license documents as well as the readable combined notices.
        for (index, license) in licenseFiles.enumerated() {
            try readFile(license).write(to: output.appendingPathComponent("license-\(index).txt"))
        }
        let unpacked = scratch.appendingPathComponent("unpacked")
        if manager.fileExists(atPath: unpacked.path) { try manager.removeItem(at: unpacked) }
        success = true
        return PreparedIconPack(pack: pack, directory: scratch, skipped: skipped)
    }

    private static func findPackRoot(_ source: URL) throws -> URL {
        let manager = FileManager.default
        func isRoot(_ url: URL) -> Bool {
            guard let root = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]), root.isDirectory == true, root.isSymbolicLink != true,
                  let icons = try? url.appendingPathComponent("icons").resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
            return icons.isDirectory == true && icons.isSymbolicLink != true
        }
        if isRoot(source) { return source }
        let children = try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        let matches = children.filter(isRoot)
        guard matches.count == 1, let root = matches.first else { throw invalid("Choose the downloaded ZIP or the extracted folder that contains both icons and LICENSE.") }
        return root
    }

    private static func readFile(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize, size <= maximumFileSize else {
            throw invalid("A file in this pack is too large or is a shortcut.")
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumFileSize else { throw invalid("A file in this pack is too large.") }
        return data
    }
    private static func readText(_ url: URL) throws -> String {
        guard let text = String(data: try readFile(url), encoding: .utf8) else { throw invalid("The pack’s license could not be read.") }
        return text
    }
    private static func invalid(_ text: String) -> IconPackImportError { .invalid(text) }

    static func validateZIP(_ url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 64 * 1024 * 1024 else { throw invalid("This ZIP is too large. Choose a download smaller than 64 MB.") }
        let data = [UInt8](try Data(contentsOf: url))
        func number(_ offset: Int, _ count: Int) -> UInt64 {
            guard offset >= 0, offset + count <= data.count else { return UInt64.max }
            return (0..<count).reduce(0) { $0 | UInt64(data[offset + $1]) << ($1 * 8) }
        }
        guard data.count >= 22,
              let end = stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1).first(where: {
                  number($0, 4) == 0x06054b50 && $0 + 22 + Int(number($0 + 20, 2)) == data.count
              }) else { throw invalid("This is not a supported ZIP file. Try downloading it again.") }
        let entries = Int(number(end + 10, 2))
        guard number(end + 4, 2) == 0, number(end + 6, 2) == 0, number(end + 8, 2) == UInt64(entries), entries <= 10000 else {
            throw invalid("This archive format is not supported. Choose a standard, unencrypted ZIP.")
        }
        var position = Int(number(end + 16, 4))
        let centralEnd = position + Int(number(end + 12, 4))
        guard position >= 0, centralEnd <= end else { throw invalid("This ZIP is damaged.") }
        var expanded: UInt64 = 0
        var names = Set<String>()
        for _ in 0..<entries {
            guard position + 46 <= centralEnd, number(position, 4) == 0x02014b50 else { throw invalid("This ZIP is damaged.") }
            let length = Int(number(position + 28, 2))
            let next = position + 46 + length + Int(number(position + 30, 2)) + Int(number(position + 32, 2))
            guard next <= centralEnd, length > 0,
                  let name = String(bytes: data[(position + 46)..<(position + 46 + length)], encoding: .utf8) else { throw invalid("This ZIP contains unsupported filenames.") }
            let mode = (number(position + 38, 4) >> 16) & 0xf000
            let parts = name.split(separator: "/", omittingEmptySubsequences: false)
            guard !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\0"), !parts.contains(".."), !parts.contains("."),
                  mode == 0 || mode == 0x8000 || mode == 0x4000,
                  names.insert(name.lowercased()).inserted,
                  number(position + 8, 2) & 1 == 0,
                  number(position + 24, 4) != UInt64(UInt32.max), number(position + 20, 4) != UInt64(UInt32.max) else {
                throw invalid("This ZIP contains unsafe paths, shortcuts, or encrypted files. Choose the original official download.")
            }
            let local = Int(number(position + 42, 4))
            guard local + 30 <= Int(number(end + 16, 4)), number(local, 4) == 0x04034b50,
                  number(local + 6, 2) & 1 == 0 else { throw invalid("This ZIP is damaged.") }
            let localNameLength = Int(number(local + 26, 2))
            let payload = local + 30 + localNameLength + Int(number(local + 28, 2))
            guard payload <= Int(number(end + 16, 4)),
                  payload + Int(number(position + 20, 4)) <= Int(number(end + 16, 4)),
                  String(bytes: data[(local + 30)..<(local + 30 + localNameLength)], encoding: .utf8) == name else {
                throw invalid("This ZIP has inconsistent filenames. Choose the original official download.")
            }
            expanded += number(position + 24, 4)
            guard expanded <= 128 * 1024 * 1024 else { throw invalid("This ZIP expands to too much data. Choose a smaller pack.") }
            position = next
        }
        guard position == centralEnd else { throw invalid("This ZIP is damaged.") }
    }

    private final class SVGValidator: NSObject, XMLParserDelegate {
        var safe = true
        private let allowed: Set<String> = ["svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "defs", "lineargradient", "radialgradient", "stop", "clippath", "mask", "title", "desc", "use"]
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
            if !allowed.contains(elementName.lowercased()) { safe = false; parser.abortParsing() }
            for (key, value) in attributes {
                let lower = key.lowercased()
                if lower.hasPrefix("on") || ((lower == "href" || lower == "xlink:href") && !value.hasPrefix("#")) || !safeCSS(value) {
                    safe = false; parser.abortParsing()
                }
            }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if !safeCSS(string) { safe = false; parser.abortParsing() }
        }
        func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
            safe = false; parser.abortParsing()
        }
        private func safeCSS(_ value: String) -> Bool {
            let text = value.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
            return !text.contains("@") && !text.contains("\\") && !text.contains("/*") && (!text.contains("url(") || !text.replacingOccurrences(of: "url(#", with: "internal(").contains("url("))
        }
    }
    static func validateSVG(_ data: Data) throws {
        guard let text = String(data: data, encoding: .utf8), !text.lowercased().contains("<!doctype"), !text.lowercased().contains("<!entity") else {
            throw invalid("This SVG contains unsupported external content.")
        }
        let validator = SVGValidator()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = validator
        guard parser.parse(), validator.safe else { throw invalid("This SVG contains unsupported or active content.") }
    }
}

@MainActor
final class ImportedIconPackStore: ObservableObject {
    static let shared = ImportedIconPackStore()
    @Published private(set) var pack: ImportedIconPack?
    private let root: URL
    private let cache = NSCache<NSString, NSImage>()

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RiverFlow/IconPacks", isDirectory: true)
        if let data = try? Data(contentsOf: self.root.appendingPathComponent("active.json")),
           let id = try? JSONDecoder().decode(UUID.self, from: data),
           let manifest = try? Data(contentsOf: self.root.appendingPathComponent(id.uuidString).appendingPathComponent("pack.json")) {
            pack = try? JSONDecoder().decode(ImportedIconPack.self, from: manifest)
        }
        cache.countLimit = 80
    }

    func install(_ prepared: PreparedIconPack) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent(prepared.pack.id.uuidString)
        try manager.copyItem(at: prepared.directory.appendingPathComponent("pack"), to: destination)
        do {
            try JSONEncoder().encode(prepared.pack.id).write(to: root.appendingPathComponent("active.json"), options: .atomic)
        } catch { try? manager.removeItem(at: destination); throw error }
        let previous = pack
        pack = prepared.pack
        cache.removeAllObjects()
        if let previous { try? manager.removeItem(at: root.appendingPathComponent(previous.id.uuidString)) }
    }

    func remove() throws {
        let pointer = root.appendingPathComponent("active.json")
        if FileManager.default.fileExists(atPath: pointer.path) { try FileManager.default.removeItem(at: pointer) }
        let previous = pack
        pack = nil
        cache.removeAllObjects()
        if let previous { try? FileManager.default.removeItem(at: root.appendingPathComponent(previous.id.uuidString)) }
    }

    func image(for icon: ImportedIconPack.Icon) -> NSImage? {
        guard let pack, pack.icons.contains(icon), icon.filename == URL(fileURLWithPath: icon.filename).lastPathComponent else { return nil }
        if let cached = cache.object(forKey: icon.filename as NSString) { return cached }
        let url = root.appendingPathComponent(pack.id.uuidString).appendingPathComponent("icons").appendingPathComponent(icon.filename)
        guard let image = NSImage(contentsOf: url), image.isValid else { return nil }
        image.size = NSSize(width: 512, height: 512)
        image.isTemplate = false
        cache.setObject(image, forKey: icon.filename as NSString)
        return image
    }
}
