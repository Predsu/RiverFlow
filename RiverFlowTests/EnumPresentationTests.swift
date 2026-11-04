import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct EnumPresentationTests {
    @Test("Sidebar items expose their display identifiers and icons")
    func sidebarItemsExposeTheirDisplayIdentifiersAndIcons() throws {
        #expect(SideBarItem.home.id == "Home")
        #expect(SideBarItem.downloads.iconName == "arrow.down.circle")
        #expect(SideBarItem.mac.url.path == "/")
    }

    @Test("File view and sorting options expose stable identifiers and icons")
    func FileViewAndSortingOptionsExposeStableIdentifiersAndIcons() throws {
        #expect(FileViewStyle.grid.id == "Grid")
        #expect(FileViewStyle.list.iconName == "list.bullet")
        #expect(FileSortOption.size.id == "Size")
        #expect(FileSortOption.modificationDate.iconName == "calendar")
        #expect(SearchScope.thisMac.id == "This Mac")
    }
}