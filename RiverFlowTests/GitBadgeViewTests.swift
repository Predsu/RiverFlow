import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct GitBadgeViewTests {
    @Test("GitBadgeView resolves badge text and color correctly")
    func gitBadgeViewResolvesBadgeTextAndColorCorrectly() throws {
        let untracked = GitBadgeView(status: "??")
        #expect(untracked.badgeText == "U")
        
        let modified = GitBadgeView(status: " M")
        #expect(modified.badgeText == "M")
        
        let added = GitBadgeView(status: "A ")
        #expect(added.badgeText == "A")
        
        let deleted = GitBadgeView(status: "D ")
        #expect(deleted.badgeText == "D")
        
        let other = GitBadgeView(status: "XY")
        #expect(other.badgeText == "XY")
    }
}