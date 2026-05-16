import SwiftUI

// MARK: - Results Sheet

struct VisualSearchResultsView: View {
    @ObservedObject var vm: VisualSearchViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ──────────────────────────────────────
                    headerView
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    // ── Label Chips ─────────────────────────────────
                    if !vm.visionLabels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.visionLabels.prefix(5), id: \.label) { item in
                                    LabelChip(text: item.label)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }

                    Divider().padding(.horizontal, 16).padding(.bottom, 12)

                    // ── Product Grid ────────────────────────────────
                    if vm.isLoading {
                        SkeletonVisualGrid()
                            .padding(.horizontal, 12)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(vm.results) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    VisualSearchCard(product: product, vm: vm)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { vm.showResults = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // ── Header view ──────────────────────────────────────────────────
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 12) {
            // Captured image thumbnail
            if let img = vm.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(UIColor.separator), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Results for your image")
                    .font(.headline)
                    .fontWeight(.bold)

                if vm.isLoading {
                    Text("Analysing…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(vm.results.count) items found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Product Card with Feedback Buttons

struct VisualSearchCard: View {
    let product: Product
    @ObservedObject var vm: VisualSearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Image
            ZStack(alignment: .bottomTrailing) {
                if let urlStr = product.imageUrl {
                    CachedImageView(urlString: urlStr) { img in
                        GeometryReader { geo in
                            img.resizable().scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.width)
                                .clipped()
                        }
                        .aspectRatio(1, contentMode: .fit)
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit).shimmer()
                    }
                    .id(urlStr)
                } else {
                    Rectangle().fill(Color(.systemGray6))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }

                // Thumbs up / down
                feedbackButtons
                    .padding(6)
            }

            // Name + price
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(.primary).lineLimit(2)
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(10)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var feedbackButtons: some View {
        let given = vm.feedbackGiven[product.id]
        HStack(spacing: 4) {
            FeedbackButton(
                icon: "hand.thumbsup.fill",
                active: given == true,
                color: .green
            ) { vm.submitFeedback(productId: product.id, wasRelevant: true) }

            FeedbackButton(
                icon: "hand.thumbsdown.fill",
                active: given == false,
                color: .red
            ) { vm.submitFeedback(productId: product.id, wasRelevant: false) }
        }
    }
}

// MARK: - Small Feedback Button

struct FeedbackButton: View {
    let icon: String
    let active: Bool
    let color: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(active ? .white : color)
                .padding(5)
                .background(
                    Circle()
                        .fill(active ? color : Color(UIColor.systemBackground).opacity(0.85))
                )
        }
        .scaleEffect(pressed ? 0.85 : 1)
    }
}

// MARK: - Label Chip

struct LabelChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(UIColor.separator), lineWidth: 0.5))
    }
}

// MARK: - Skeleton Grid while loading

struct SkeletonVisualGrid: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<8, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                        .shimmer()
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 10).shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 60, height: 10).shimmer()
                    }
                    .padding(10)
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
        }
    }
}
