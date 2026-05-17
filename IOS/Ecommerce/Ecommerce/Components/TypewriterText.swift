import SwiftUI
import Combine

// MARK: - Typewriter Text (Extracted from ChatBubble.swift)
// Animates text character-by-character for AI-generated content.
// Used across all views where the AI "produces" text.
struct TypewriterText: View {
    let fullText: String
    let messageId: UUID
    @State private var displayedText: String = ""
    @State private var isFinished: Bool = false

    // Track which messages have already been animated so we don't re-animate on scroll
    static var animatedIDs: Set<UUID> = []

    var body: some View {
        Text(isFinished ? fullText : displayedText)
            .onAppear {
                if Self.animatedIDs.contains(messageId) {
                    isFinished = true
                    displayedText = fullText
                } else {
                    typeOut()
                }
            }
            .onChange(of: fullText) { oldValue, newValue in
                // If the text actually changes (e.g., fallback update), we should reset and re-type
                if newValue != fullText {
                    displayedText = ""
                    isFinished = false
                    typeOut()
                }
            }
    }

    private func typeOut() {
        Task {
            Self.animatedIDs.insert(messageId)
            var tempStr = ""
            for char in fullText {
                // If the user scrolls away and view is destroyed, Task can be cancelled
                if Task.isCancelled { break }
                tempStr.append(char)
                await MainActor.run { displayedText = tempStr }
                // 15ms per character creates a fast, natural typing feel
                try? await Task.sleep(nanoseconds: 15_000_000)
            }
            await MainActor.run { isFinished = true }
        }
    }
}
