import SwiftUI
import PhotosUI

struct ChatView: View {
    var initialBubbleMessage: String? = nil

    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var aiPresence: AIPresenceManager
    @Environment(\.dismiss) var dismiss
    @State private var placeholderIndex = 0

    private let placeholders = [
        "Ask me anything…",
        "Looking for a gift idea?",
        "I can style a table for you",
        "Try: 'cast iron under $50'",
        "What occasion are you shopping for?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message, viewModel: viewModel)
                                    .id(message.id)
                            }
                            // Invisible bottom anchor — always rendered last
                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // New message added
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    // Loading spinner appears/disappears
                    .onChange(of: viewModel.isLoading) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    // Last message text grows (TypewriterText ticks)
                    .onChange(of: viewModel.messages.last?.text) { _, _ in
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }

                // Quick Replies
                if let lastMessage = viewModel.messages.last,
                   !lastMessage.isLoading {
                    ForEach(Array(lastMessage.attachments.enumerated()), id: \.offset) { _, attachment in
                        if case .quickReplies(let replies) = attachment {
                            ChatQuickReplies(replies: replies, viewModel: viewModel)
                                .padding(.vertical, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }

                Divider()

                // Input bar
                ChatInputBar(viewModel: viewModel, placeholders: placeholders, placeholderIndex: placeholderIndex)
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.messages.removeAll()
                        viewModel.sendWelcomeMessage()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .onAppear {
                viewModel.cartManager = cartManager
                viewModel.productViewModel = productViewModel
                viewModel.context.lastViewedProductId = productViewModel.activeProductId
                viewModel.messages.removeAll()
                viewModel.sendWelcomeMessage(withBubbleContext: initialBubbleMessage)
                aiPresence.isAIActive = true
                aiPresence.dismissBubble()

                // Cycle placeholder text
                Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                    Task { @MainActor in
                        placeholderIndex = (placeholderIndex + 1) % placeholders.count
                    }
                }
            }
            .onDisappear {
                aiPresence.isAIActive = false
            }
        }
    }

    /// Scrolls to the bottom anchor.
    /// - `animated: true`  → smooth spring (used when a full new message arrives)
    /// - `animated: false` → instant jump  (used while TypewriterText is ticking)
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        // Task @MainActor guarantees we run *after* SwiftUI finishes its current
        // layout pass, so the scroll target height is already correct.
        Task { @MainActor in
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
        }
    }
}


// MARK: - Input Bar
struct ChatInputBar: View {
    @ObservedObject var viewModel: ChatViewModel
    let placeholders: [String]
    let placeholderIndex: Int
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        HStack(spacing: 10) {
            // Image attach
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .onChange(of: selectedItem) { oldValue, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.selectedImage = uiImage
                            viewModel.context.hasAttachedImage = true
                            viewModel.sendMessage()
                        }
                    }
                }
            }

            // Text field
            TextField(placeholders.indices.contains(placeholderIndex) ? placeholders[placeholderIndex] : "Ask me anything…", text: $viewModel.inputText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(Capsule())
                .onSubmit { viewModel.sendMessage() }
                .animation(.easeInOut(duration: 0.3), value: placeholderIndex)

            // Send / mic
            if viewModel.inputText.isEmpty {
                Button(action: { /* activate SFSpeechRecognizer in future */ }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: {
                    viewModel.sendMessage()
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    ZStack {
                        Circle().fill(Color.black).frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
