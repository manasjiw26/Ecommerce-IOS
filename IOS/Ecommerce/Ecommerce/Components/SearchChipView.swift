import SwiftUI

struct SearchChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.primary : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? Color(UIColor.systemBackground) : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
