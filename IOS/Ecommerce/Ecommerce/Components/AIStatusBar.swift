import SwiftUI
import Combine

// MARK: - AI Status Bar
// A cycling single-line status text that shows AI activity messages.
// Used in ProductListView and RegistryLandingView to show ambient AI presence.
struct AIStatusBar: View {
    let messages: [String]
    var interval: TimeInterval = 6.0
    @State private var index = 0
    @State private var visible = true

    var body: some View {
        Text(messages[index])
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(.secondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: visible)
            .onAppear { startCycling() }
    }

    private func startCycling() {
        guard messages.count > 1 else { return }
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation { visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                index = (index + 1) % messages.count
                withAnimation { visible = true }
            }
        }
    }
}
