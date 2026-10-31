import AppKit
import Darwin

/// Uses macOS custom icons so the same icon is visible outside RiverFlow.
@MainActor
enum FileCustomIconService {
    static let didChange = Notification.Name("RiverFlow.fileIconDidChange")

    enum IconError: LocalizedError {
        case invalidImage, cannotWrite, symbolicLink
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "This image could not be used as an icon. Choose another image."
            case .cannotWrite: return "macOS could not change this icon. Check that you have permission to modify this item and that its volume is writable."
            case .symbolicLink: return "Change the original item’s icon instead of the symbolic link’s icon."
            }
        }
    }

    /// Foundation's customIcon resource key is unimplemented. Read the Finder flag instead.
    static func hasCustomIcon(at url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            var info = [UInt8](repeating: 0, count: 32)
            let count = getxattr(path, "com.apple.FinderInfo", &info, info.count, 0, XATTR_NOFOLLOW)
            guard count >= 10 else { return false }
            let flags = UInt16(info[8]) << 8 | UInt16(info[9])
            return flags & 0x0400 != 0
        }
    }

    static func apply(_ image: NSImage?, to url: URL) throws {
        // NSWorkspace may resolve links. Avoid silently modifying another item.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else { throw IconError.symbolicLink }
        if let image, !image.isValid { throw IconError.invalidImage }
        guard NSWorkspace.shared.setIcon(image, forFile: url.path, options: []) else { throw IconError.cannotWrite }
        NotificationCenter.default.post(name: didChange, object: url)
    }

    /// Rasterize the symbol at multiple resolutions; saved icons do not depend on appearance.
    static func symbolIcon(named name: String, color: NSColor) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let icon = NSImage(size: NSSize(width: 512, height: 512))
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap),
                  let rendered = symbol.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.72, weight: .regular)
                        .applying(.init(paletteColors: [color]))) else { return nil }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            NSColor.clear.setFill()
            NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
            let available = CGFloat(size) * 0.8
            let scale = available / max(rendered.size.width, rendered.size.height)
            let width = rendered.size.width * scale
            let height = rendered.size.height * scale
            rendered.draw(in: NSRect(x: (CGFloat(size) - width) / 2, y: (CGFloat(size) - height) / 2,
                                     width: width, height: height), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            icon.addRepresentation(bitmap)
        }
        icon.isTemplate = false
        return icon
    }
}
