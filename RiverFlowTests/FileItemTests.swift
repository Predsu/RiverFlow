import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct FileItemTests {
    private static func makeItem(
        url: URL = URL(fileURLWithPath: "/tmp/test.txt"),
        name: String = "test.txt",
        itemType: FileItemType = .FILE,
        size: Int64? = nil,
        modificationDate: Date? = nil,
        isHidden: Bool = false
    ) -> FileItem {
        FileItem(url: url, name: name, itemType: itemType, size: size, modificationDate: modificationDate, isHidden: isHidden)
    }
    
    @Test("formattedSize formats byte count")
    func formattedSizeFormatsByteCount() async throws {
        let item = Self.makeItem(size: 1024)
        let item2 = Self.makeItem(size: 3123)
        
        #expect(item.formattedSize != "--")
        #expect(!item.formattedSize.isEmpty)
        #expect(item.formattedSize == "1 KB")
        
        #expect(item2.formattedSize != "--")
        #expect(!item2.formattedSize.isEmpty)
        #expect(item2.formattedSize == "3 KB")
    }
    
    @Test("formattedSize returns a placeholder when size is nil")
    func formattedSizeReturnsPlaceholderWhenSizeIsNil() async throws {
        let item = Self.makeItem(size: nil)
        
        #expect(item.formattedSize == "--")
    }
    
    @Test("formattedSize handles 0 bytes without falling back to the placeholder")
    func formattedSizeHandlesZeroBytesWithoutFallingBackToPlaceholder() async throws {
        let item = Self.makeItem(size: 0)
        
        #expect(item.formattedSize != "--")
    }
    
    @Test("formattedDate returns a placeholder when the date is nil")
    func formattedDateReturnsPlaceholderWhenTheDateIsNil() async throws {
        let item = Self.makeItem(modificationDate: nil)
        
        #expect(item.formattedDate == "--")
    }
    
    @Test("formattedDate returns a non-empty string for a known date")
    func formattedDateReturnsANonEmptyStringForAKnownDate() async throws{
        let item = Self.makeItem(modificationDate: Date())
        
        #expect(item.formattedDate != "--")
        #expect(!item.formattedDate.isEmpty)
    }
    
    @Test("fileExtensionIconText is empty when there is no extension")
    func fileExtensionIconTextIsEmptyWhenThereIsNoExtension() async throws {
        let item = Self.makeItem(url: URL(fileURLWithPath: "/tmp/TESTNOEX"), name: "TESTNOEX")
        
        #expect(item.fileExtensionIconText == "")
    }

    @Test("fileExtensionIconText uppercases file extension")
    func fileExtensionIconTextUppercasesFileExtension() throws {
        let item = Self.makeItem(url: URL(fileURLWithPath: "/tmp/report.Pdf"))

        #expect(item.fileExtensionIconText == "PDF")
    }
    
    @Test("Two FileItem instances for the same URL still have distinct identities")
    func twoFileItemInstancesForTheSameURLStillHaveDistinctIdentities() async throws{
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let a = Self.makeItem(url: url)
        let b = Self.makeItem(url: url)
        
        #expect(a.id != b.id)
    }
}