import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @Environment(\.dismiss) var dismiss
    @State private var scrollProxy: ScrollViewProxy? = nil

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
                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isLoading) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                // Quick Replies (Recommended Prompts)
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
                ChatInputBar(viewModel: viewModel)
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
                    Button(action: { viewModel.messages.removeAll(); viewModel.sendWelcomeMessage() }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .onAppear {
                viewModel.cartManager = cartManager
                viewModel.productViewModel = productViewModel
                viewModel.context.lastViewedProductId = productViewModel.activeProductId
                viewModel.messages.removeAll()
                viewModel.sendWelcomeMessage()
            }
        }
    }
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
        }
    }
}

// MARK: - Input Bar
struct ChatInputBar: View {
    @ObservedObject var viewModel: ChatViewModel
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
            TextField("Ask me anything…", text: $viewModel.inputText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(Capsule())
                .onSubmit { viewModel.sendMessage() }

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
