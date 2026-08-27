import SwiftUI

struct GitBadgeView: View {
    let status: String
    
    var badgeText: String {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "??" { return "U" }
        if trimmed.contains("M") || trimmed.contains("m") { return "M" }
        if trimmed.contains("A") || trimmed.contains("a") { return "A" }
        if trimmed.contains("D") { return "D" }
        return trimmed.uppercased()
    }
    
    var body: some View {
        Text(badgeText)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .cornerRadius(3)
    }
    
    private var color: Color {
        let txt = badgeText
        switch txt {
        case "M": return .orange
        case "A": return .green
        case "U": return .secondary
        case "D": return .red
        default: return .secondary
        }
    }
}
