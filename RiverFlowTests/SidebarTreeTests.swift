import Foundation
import Testing
@testable import RiverFlow

@Suite struct SidebarTreeTests {
    private func fixture() throws -> (URL, [SidebarNode]) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for path in ["Projects/App/Sources/Deep", "Projects/Other/Child", "Downloads/Incoming", ".hidden/Nested"] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        return (directory, [
            SidebarNode(name: "All", url: directory, iconName: "desktopcomputer", isRoot: true),
            SidebarNode(name: "Projects", url: directory.appendingPathComponent("Projects"), iconName: "folder", isRoot: true),
            SidebarNode(name: "Downloads", url: directory.appendingPathComponent("Downloads"), iconName: "folder", isRoot: true)
        ])
    }

    @Test("Deep navigation reveals only the closest shortcut and closes previous branches")
    func deepNavigationRevealsOnlyTheClosestShortcutAndClosesPreviousBranches() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deep = directory.appendingPathComponent("Projects/App/Sources/Deep")
        let model = FolderViewModel(startDir: deep, sidebarRoots: roots)
        #expect(!roots[0].isExpanded)
        #expect(roots[1].isExpanded)
        #expect(!roots[2].isExpanded)
        #expect(model.visibleSidebarEntries.first { $0.id == model.selectedSidebarNodeID }?.node.url == deep)
        let app = try #require(roots[1].children.first { $0.name == "App" })
        #expect(app.isExpanded)
        model.navigateTo(url: directory.appendingPathComponent("Downloads/Incoming"))
        #expect(!roots[1].isExpanded)
        #expect(!app.isExpanded)
        #expect(roots[2].isExpanded)
        #expect(!model.visibleSidebarEntries.contains { $0.node.url == deep })
    }

    @Test("Duplicate folder occurrences have unique identities and retain explicit navigation root")
    func duplicateFolderOccurrencesHaveUniqueIndentitiesAndRetainExplicitNavigationRoot() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = FolderViewModel(startDir: directory, sidebarRoots: roots)
        model.toggleSidebarNode(roots[0])
        let projects = try #require(roots[0].children.first { $0.name == "Projects" })
        #expect(projects.url == roots[1].url)
        #expect(projects.id != roots[1].id)
        model.selectSidebarNode(projects.id)
        #expect(model.selectedSidebarNodeID == projects.id)
        #expect(model.currentDir == projects.url)
        #expect(roots[0].isExpanded)
        #expect(!roots[1].isExpanded)
        model.navigateTo(url: directory.appendingPathComponent("Projects/App/Sources/Deep"))
        #expect(roots[0].isExpanded)
        #expect(!roots[1].isExpanded)
        #expect(model.visibleSidebarEntries.filter { $0.id == model.selectedSidebarNodeID }.count == 1)
        model.goBackward()
        #expect(model.selectedSidebarNodeID == projects.id)
    }

    @Test("Refresh preserves row identity and respects manual collapse")
    func refreshPreservesRowIdentityAndRespectsManualCollapse() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = FolderViewModel(startDir: directory.appendingPathComponent("Projects/App/Sources/Deep"), sidebarRoots: roots)
        let selectedID = model.selectedSidebarNodeID
        model.loadCurrentDirectory()
        #expect(model.selectedSidebarNodeID == selectedID)
        #expect(model.visibleSidebarEntries.contains { $0.id == selectedID })
        model.collapseSidebar()
        model.loadCurrentDirectory()
        #expect(model.visibleSidebarEntries.count == roots.count)
        #expect(roots.allSatisfy { !$0.isExpanded })
        model.toggleSidebarNode(roots[1])
        #expect(roots[1].children.allSatisfy { !$0.isExpanded && !$0.isLoaded })
        model.expandToURL(model.currentDir)
        #expect(model.selectedSidebarNodeID == selectedID)
        #expect(model.visibleSidebarEntries.contains { $0.id == selectedID })
    }

    @Test("Refresh does not recursively load collapsed subtrees")
    func refreshDoesNotRecursivelyLoadCollapsedSubtrees() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = FolderViewModel(startDir: directory.appendingPathComponent("Projects/App"), sidebarRoots: roots)
        let other = try #require(roots[1].children.first { $0.name == "Other" })
        model.toggleSidebarNode(other)
        let child = try #require(other.children.first)
        model.toggleSidebarNode(other)
        model.reloadSidebarTree()
        #expect(!other.isLoaded)
        #expect(!child.isLoaded)
        #expect(!other.isExpanded)
    }

    @Test("Hidden-only folders expose disclosure when hidden files are enabled")
    func hiddenOnlyFoldersExposeDisclosureWhenHiddenFilesAreEnabled() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent(".hidden"), withIntermediateDirectories: true)
        let node = SidebarNode(name: "Root", url: directory, iconName: "folder")
        node.loadChildren(showHidden: false)
        #expect(!node.hasSubfolders(showHidden: false))
        #expect(node.hasSubfolders(showHidden: true))
        #expect(node.children.map(\.name) == [".hidden"])
        #expect(!node.hasSubfolders(showHidden: false))
    }

    @Test("An ancestor must match whole path components")
    func anAncestorMustMatchWholePathComponents() {
        let root = URL(fileURLWithPath: "/tmp/Project")
        #expect(SidebarNode.contains(root.appendingPathComponent("Sources"), in: root))
        #expect(!SidebarNode.contains(URL(fileURLWithPath: "/tmp/Project-copy"), in: root))
    }

    @Test("Arrow keys expand and collapse before navigating to a child or parent")
    func arrowKeysExpandAndCollapseBeforeNavigatingToChildOrParent() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = FolderViewModel(startDir: roots[1].url, sidebarRoots: roots)
        model.moveInSidebar(expanding: true)
        #expect(roots[1].isExpanded)
        #expect(model.currentDir == roots[1].url)
        model.moveInSidebar(expanding: false)
        #expect(!roots[1].isExpanded)
        #expect(model.currentDir == roots[1].url)
        model.moveInSidebar(expanding: true)
        model.moveInSidebar(expanding: true)
        #expect(model.currentDir == roots[1].url.appendingPathComponent("App"))
        model.moveInSidebar(expanding: false)
        #expect(model.currentDir == roots[1].url)
        #expect(model.selectedSidebarNodeID == roots[1].id)
    }

    @Test("Favorites accept directories once, persist in order, and leave files in place")
    func favoritesAcceptDirectoriesOncePersistInOrderAndLeaveFilesInPlace() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "SidebarFavoritesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = FolderViewModel(startDir: directory, sidebarRoots: roots, sidebarDefaults: defaults)
        let file = directory.appendingPathComponent("notes.txt")
        try Data("test".utf8).write(to: file)
        let package = directory.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        #expect(!model.addSidebarFavorites([file, package, URL(string: "https://example.com")!, directory.appendingPathComponent("missing")]))
        #expect(model.addSidebarFavorites([roots[1].url, roots[2].url, roots[1].url.appendingPathComponent(".")]))
        #expect(model.favoriteSidebarRoots.map(\.url) == [roots[1].url, roots[2].url])
        #expect(model.addSidebarFavorites([roots[1].url]))
        #expect(model.favoriteSidebarRoots.count == 2)
        #expect(FileManager.default.fileExists(atPath: roots[1].url.path))
        #expect(try String(contentsOf: file, encoding: .utf8) == "test")
        let restored = FolderViewModel(startDir: directory, sidebarRoots: roots, sidebarDefaults: defaults)
        #expect(restored.favoriteSidebarRoots.map(\.url) == [roots[1].url, roots[2].url])
        restored.removeSidebarFavorite(restored.favoriteSidebarRoots[0])
        let afterRemoval = FolderViewModel(startDir: directory, sidebarRoots: roots, sidebarDefaults: defaults)
        #expect(afterRemoval.favoriteSidebarRoots.map(\.url) == [roots[2].url])
        #expect(FileManager.default.fileExists(atPath: roots[1].url.path))
    }

    @Test("Favorite trees support navigation and fall back to Locations when removed")
    func favoriteTreesSupportNavigationAndFallBackToLocationsWhenRemoved() throws {
        let (directory, roots) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "SidebarFavoritesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = FolderViewModel(startDir: directory, sidebarRoots: roots, sidebarDefaults: defaults)
        model.addSidebarFavorites([roots[1].url])
        let favorite = try #require(model.favoriteSidebarRoots.first)
        #expect(favorite.id != roots[1].id)
        model.selectSidebarNode(favorite.id)
        #expect(model.currentDir == favorite.url)
        #expect(model.selectedSidebarNodeID == favorite.id)
        model.moveInSidebar(expanding: true)
        #expect(favorite.isExpanded)
        model.moveInSidebar(expanding: true)
        #expect(model.currentDir == favorite.url.appendingPathComponent("App"))
        model.navigateTo(url: favorite.url.appendingPathComponent("App/Sources/Deep"))
        let selected = try #require(model.visibleSidebarEntries.first { $0.id == model.selectedSidebarNodeID })
        #expect(selected.rootID == favorite.id)
        model.loadCurrentDirectory()
        #expect(model.selectedSidebarNodeID == selected.id)
        model.removeSidebarFavorite(favorite)
        #expect(model.currentDir == selected.node.url)
        #expect(model.favoriteSidebarRoots.isEmpty)
        let fallback = try #require(model.visibleSidebarEntries.first { $0.id == model.selectedSidebarNodeID })
        #expect(fallback.rootID == roots[1].id)
        #expect(fallback.node.url == model.currentDir)
    }

}
