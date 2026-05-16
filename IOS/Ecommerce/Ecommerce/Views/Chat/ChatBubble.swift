import SwiftUI
import Combine

struct ChatBubble: View {
    let message: ChatMessage
    let viewModel: ChatViewModel

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.role == .user { Spacer(minLength: 0) }

                if message.role == .assistant {
                    // Bot avatar
                    ZStack {
                        Circle().fill(Color.black).frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                if message.isLoading {
                    TypingIndicator()
                } else if !message.text.isEmpty {
                    if message.role == .assistant {
                        TypewriterText(fullText: message.text, messageId: message.id)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(BubbleShape(isUser: false))
                            .frame(maxWidth: 280, alignment: .leading)
                    } else {
                        Text(message.text)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(BubbleShape(isUser: true))
                            .frame(maxWidth: 280, alignment: .trailing)
                    }
                }

                if message.role == .assistant { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity)

            // Attachments
            if !message.isLoading {
                ForEach(Array(message.attachments.enumerated()), id: \.offset) { _, attachment in
                    let isProducts: Bool = {
                        if case .products = attachment { return true }
                        return false
                    }()
                    attachmentView(for: attachment)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, (message.role == .assistant && !isProducts) ? 36 : 0)
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func attachmentView(for attachment: ChatAttachment) -> some View {
        switch attachment {
        case .products(let products):
            ChatProductCarousel(products: products, viewModel: viewModel)
        case .order(let order):
            ChatOrderCard(order: order)
        case .quickReplies(_):
            EmptyView()
        case .cartSummary:
            Text("") // Empty view since the summary is in the text itself
        case .priceComparison(let a, let b):
            ChatComparisonCard(productA: a, productB: b)
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(phase == i ? 1.0 : 0.3))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: phase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(Capsule())
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Bubble shape
struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        return path
    }
}

// MARK: - Typewriter Text
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
