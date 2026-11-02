import Foundation
import UniformTypeIdentifiers
import ImageIO
import PDFKit
import Darwin

struct FileInfoField: Identifiable, Sendable {
    var id: String { label }
    let label: String
    let value: String
    var monospaced = false
}

struct FileInfoSection: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let symbol: String
    let fields: [FileInfoField]
    var note: String? = nil
}

/// A read-only snapshot. Potentially expensive metadata reads run outside the UI task.
struct FileInfoMetadata: Sendable {
    var kind = "File"
    var general: [FileInfoSection] = []
    var details: [FileInfoSection] = []
    var permissions: [FileInfoSection] = []

    static func read(at url: URL) throws -> Self {
        let manager = FileManager.default
        let attributes = try manager.attributesOfItem(atPath: url.path)
        let values = (try? url.resourceValues(forKeys: [
            .contentTypeKey, .creationDateKey, .contentModificationDateKey,
            .contentAccessDateKey, .isHiddenKey, .isPackageKey,
            .volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeIsReadOnlyKey
        ])) ?? URLResourceValues()
        var info = Self()
        let isLink = attributes[.type] as? FileAttributeType == .typeSymbolicLink
        let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
        info.kind = isLink ? "Symbolic link" : (values.contentType?.localizedDescription ?? (isDirectory ? "Folder" : "File"))
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        var status = stat()
        let hasStat = url.withUnsafeFileSystemRepresentation { path in
            path.map { lstat($0, &status) == 0 } ?? false
        }
        var storage: [FileInfoField] = []
        if !isDirectory {
            storage.append(.init(label: "Size", value: formatBytes(bytes)))
            storage.append(.init(label: "Exact size", value: "\(bytes.formatted()) bytes"))
            if hasStat {
                storage.append(.init(label: "On disk", value: formatBytes(Int64(status.st_blocks) * 512)))
            }
        }
        info.general = [
            .init(title: "Identity", symbol: "doc.text", fields: [
                .init(label: "Kind", value: info.kind),
                .init(label: "Location", value: url.deletingLastPathComponent().path),
                .init(label: "Hidden", value: values.isHidden.map { $0 ? "Yes" : "No" } ?? "Unavailable"),
                .init(label: "Package", value: values.isPackage.map { $0 ? "Yes" : "No" } ?? "Unavailable")
            ]),
            .init(title: "Storage", symbol: "internaldrive", fields: storage,
                  note: isDirectory ? "Folder totals are calculated separately." : "On-disk allocation can differ from file size due to compression, sparse data, and filesystem sharing."),
            .init(title: "Dates", symbol: "calendar", fields: [
                .init(label: "Created", value: date(attributes[.creationDate] as? Date)),
                .init(label: "Modified", value: date(attributes[.modificationDate] as? Date)),
                .init(label: "Accessed", value: date(hasStat ? Date(timeIntervalSince1970: TimeInterval(status.st_atimespec.tv_sec)) : nil))
            ], note: "Access times depend on the filesystem and may not reflect the last time a file was opened.")
        ]
        var identity: [FileInfoField] = [
            .init(label: "Type identifier", value: values.contentType?.identifier ?? "Unavailable", monospaced: true),
            .init(label: "Extension", value: url.pathExtension.isEmpty ? "None" : url.pathExtension),
            .init(label: "MIME type", value: values.contentType?.preferredMIMEType ?? "Unavailable", monospaced: true)
        ]
        if hasStat {
            identity += [
                .init(label: "Inode", value: String(status.st_ino), monospaced: true),
                .init(label: "Device ID", value: String(status.st_dev), monospaced: true),
                .init(label: "Hard links", value: String(status.st_nlink))
            ]
        }
        if isLink {
            identity.append(.init(label: "Link target", value: (try? manager.destinationOfSymbolicLink(atPath: url.path)) ?? "Unavailable"))
        }
        info.details = [
            .init(title: "File system", symbol: "externaldrive", fields: identity),
            .init(title: "Volume", symbol: "internaldrive", fields: [
                .init(label: "Name", value: values.volumeName ?? "Unavailable"),
                .init(label: "Format", value: values.volumeLocalizedFormatDescription ?? "Unavailable"),
                .init(label: "Read-only", value: values.volumeIsReadOnly.map { $0 ? "Yes" : "No" } ?? "Unavailable")
            ])
        ]
        if !isLink, let content = contentDetails(at: url, type: values.contentType) {
            info.details.insert(content, at: 0)
        }
        info.details.append(extendedAttributes(at: url))
        let mode = (attributes[.posixPermissions] as? NSNumber)?.uint16Value
        var ownership: [FileInfoField] = [
            .init(label: "Owner", value: attributes[.ownerAccountName] as? String ?? "Unavailable"),
            .init(label: "Owner ID", value: (attributes[.ownerAccountID] as? NSNumber)?.stringValue ?? "Unavailable", monospaced: true),
            .init(label: "Group", value: attributes[.groupOwnerAccountName] as? String ?? "Unavailable"),
            .init(label: "Group ID", value: (attributes[.groupOwnerAccountID] as? NSNumber)?.stringValue ?? "Unavailable", monospaced: true)
        ]
        if let mode {
            ownership.append(.init(label: "Mode", value: String(format: "%04o", Int(mode)), monospaced: true))
        }
        info.permissions = [.init(title: "Ownership", symbol: "person.2", fields: ownership)]
        if let mode {
            info.permissions.append(.init(title: "POSIX permissions", symbol: "lock.shield", fields: [
                .init(label: "Owner", value: accessDescription(mode >> 6, directory: isDirectory)),
                .init(label: "Group", value: accessDescription(mode >> 3, directory: isDirectory)),
                .init(label: "Everyone", value: accessDescription(mode, directory: isDirectory))
            ], note: "These are the Unix mode bits. Access control lists, file flags, and macOS privacy restrictions can also affect access."))
        }
        info.permissions.append(.init(title: "Current user", symbol: "person.crop.circle.badge.checkmark", fields: [
            .init(label: "Read", value: manager.isReadableFile(atPath: url.path) ? "Allowed" : "Not allowed"),
            .init(label: "Write", value: manager.isWritableFile(atPath: url.path) ? "Allowed" : "Not allowed"),
            .init(label: isDirectory ? "Traverse" : "Execute", value: manager.isExecutableFile(atPath: url.path) ? "Allowed" : "Not allowed"),
            .init(label: "Immutable", value: (attributes[.immutable] as? Bool).map { $0 ? "Yes" : "No" } ?? "Unavailable")
        ], note: isLink ? "Current-user access checks follow the link to its target. Ownership and mode describe the link itself." : "Access reported for RiverFlow’s current user and process."))
        return info
    }

    private static func accessDescription(_ bits: UInt16, directory: Bool) -> String {
        let labels = [(UInt16(4), "Read"), (UInt16(2), "Write"), (UInt16(1), directory ? "Traverse" : "Execute")]
        let enabled = labels.compactMap { bits & $0.0 != 0 ? $0.1 : nil }
        return enabled.isEmpty ? "No access" : enabled.joined(separator: ", ")
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func date(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "Unavailable"
    }

    private static func contentDetails(at url: URL, type: UTType?) -> FileInfoSection? {
        if type?.conforms(to: .image) == true,
           let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            var fields: [FileInfoField] = []
            if let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
               let height = properties[kCGImagePropertyPixelHeight] as? NSNumber {
                fields.append(.init(label: "Dimensions", value: "\(width) × \(height) pixels"))
            }
            if let depth = properties[kCGImagePropertyDepth] as? NSNumber {
                fields.append(.init(label: "Bit depth", value: "\(depth) bits per channel"))
            }
            if let model = properties[kCGImagePropertyColorModel] as? String {
                fields.append(.init(label: "Color model", value: model))
            }
            if let profile = properties[kCGImagePropertyProfileName] as? String {
                fields.append(.init(label: "Profile", value: profile))
            }
            fields.append(.init(label: "Images", value: String(CGImageSourceGetCount(source))))
            return .init(title: "Image", symbol: "photo", fields: fields)
        }
        if type?.conforms(to: .pdf) == true, let document = PDFDocument(url: url) {
            var fields: [FileInfoField] = [
                .init(label: "Pages", value: document.pageCount.formatted()),
                .init(label: "PDF version", value: "\(document.majorVersion).\(document.minorVersion)"),
                .init(label: "Encrypted", value: document.isEncrypted ? "Yes" : "No")
            ]
            for (label, key) in [("Title", PDFDocumentAttribute.titleAttribute), ("Author", .authorAttribute), ("Producer", .producerAttribute)] {
                if let value = document.documentAttributes?[key] as? String, !value.isEmpty {
                    fields.append(.init(label: label, value: value))
                }
            }
            return .init(title: "Document", symbol: "doc.richtext", fields: fields)
        }
        return nil
    }

    private static func extendedAttributes(at url: URL) -> FileInfoSection {
        let names: [String]? = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return nil }
            let count = listxattr(path, nil, 0, XATTR_NOFOLLOW)
            guard count >= 0 else { return nil }
            guard count > 0 else { return [] }
            var buffer = [CChar](repeating: 0, count: count)
            let read = listxattr(path, &buffer, buffer.count, XATTR_NOFOLLOW)
            guard read >= 0 else { return nil }
            return buffer.prefix(read).split(separator: 0).map { bytes in
                String(decoding: bytes.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            }.sorted()
        }
        return .init(title: "Extended attributes", symbol: "list.bullet.rectangle", fields: [
            .init(label: "Attributes", value: names.map { $0.isEmpty ? "None" : $0.joined(separator: "\n") } ?? "Unavailable", monospaced: true)
        ], note: "Attribute names only; values are not loaded.")
    }
}

struct FileInfoFolderSummary: Sendable {
    var bytes: Int64 = 0
    var allocatedBytes: Int64 = 0
    var files = 0
    var folders = 0
    var unreadableItems = 0

    static func read(at url: URL) -> Self {
        var result = Self()
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [], errorHandler: { _, _ in
            result.unreadableItems += 1
            return !Task.isCancelled
        }) else {
            result.unreadableItems += 1
            return result
        }
        for case let child as URL in enumerator {
            if Task.isCancelled { break }
            var status = stat()
            let found = child.withUnsafeFileSystemRepresentation { path in
                path.map { lstat($0, &status) == 0 } ?? false
            }
            guard found else { result.unreadableItems += 1; continue }
            if status.st_mode & S_IFMT == S_IFDIR {
                result.folders += 1
            } else {
                result.files += 1
                result.bytes += Int64(status.st_size)
                result.allocatedBytes += Int64(status.st_blocks) * 512
            }
        }
        return result
    }
}
