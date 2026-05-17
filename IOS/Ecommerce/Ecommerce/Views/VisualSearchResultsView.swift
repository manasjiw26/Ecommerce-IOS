import SwiftUI

// MARK: - Results Sheet

struct VisualSearchResultsView: View {
    @ObservedObject var vm: VisualSearchViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private var isAesthetic: Bool { vm.searchMode == .aesthetic }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ──────────────────────────────────────
                    headerView
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, isAesthetic ? 8 : 12)

                    // ── Aesthetic Palette Banner ─────────────────────
                    if isAesthetic && !vm.detectedColors.isEmpty {
                        aestheticBannerView
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }

                    // ── Label Chips (object mode only) ───────────────
                    if !isAesthetic && !vm.visionLabels.isEmpty {
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

                    // ── Product Grid ─────────────────────────────────
                    if vm.isLoading {
                        SkeletonVisualGrid()
                            .padding(.horizontal, 12)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(vm.results) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    VisualSearchCard(product: product, vm: vm, isAesthetic: isAesthetic)
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

    // ── Aesthetic palette banner ──────────────────────────────────────
    @ViewBuilder
    private var aestheticBannerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Palette detected in your photo")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(spacing: 8) {
                ForEach(vm.detectedColors, id: \.self) { colorName in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(swatchColor(for: colorName))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                        Text(colorName.capitalized)
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }

    // ── Header view ──────────────────────────────────────────────────
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 12) {
            if let img = vm.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(UIColor.separator), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isAesthetic ? "Aesthetic matches" : "Results for your image")
                    .font(.headline)
                    .fontWeight(.bold)

                if vm.isLoading {
                    Text(isAesthetic ? "Analysing room palette…" : "Analysing…")
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

    // ── Color name → approximate swatch Color ────────────────────────
    private func swatchColor(for name: String) -> Color {
        switch name.lowercased() {
        case "white":                return Color(white: 0.97)
        case "cream":                return Color(red: 0.98, green: 0.95, blue: 0.87)
        case "beige":                return Color(red: 0.96, green: 0.90, blue: 0.79)
        case "tan":                  return Color(red: 0.82, green: 0.71, blue: 0.55)
        case "brown":                return Color(red: 0.55, green: 0.37, blue: 0.23)
        case "black":                return Color(white: 0.08)
        case "grey", "gray":         return Color(white: 0.60)
        case "charcoal":             return Color(white: 0.25)
        case "navy":                 return Color(red: 0.10, green: 0.13, blue: 0.35)
        case "blue":                 return Color(red: 0.24, green: 0.47, blue: 0.85)
        case "sage":                 return Color(red: 0.60, green: 0.73, blue: 0.61)
        case "green":                return Color(red: 0.22, green: 0.62, blue: 0.35)
        case "teal":                 return Color(red: 0.15, green: 0.58, blue: 0.60)
        case "red":                  return Color(red: 0.85, green: 0.18, blue: 0.18)
        case "rust":                 return Color(red: 0.72, green: 0.32, blue: 0.18)
        case "terracotta":           return Color(red: 0.80, green: 0.45, blue: 0.30)
        case "blush":                return Color(red: 0.95, green: 0.76, blue: 0.76)
        case "pink":                 return Color(red: 0.97, green: 0.60, blue: 0.73)
        case "orange":               return Color(red: 0.95, green: 0.55, blue: 0.20)
        case "gold":                 return Color(red: 0.85, green: 0.72, blue: 0.25)
        case "lavender":             return Color(red: 0.72, green: 0.65, blue: 0.90)
        default:                     return Color(UIColor.systemGray4)
        }
    }
}


// MARK: - Product Card with Feedback Buttons

struct VisualSearchCard: View {
    let product: Product
    @ObservedObject var vm: VisualSearchViewModel
    let isAesthetic: Bool

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
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, isAesthetic && product.aiReasoning != nil ? 6 : 10)

            // ── Aesthetic reason strip (only in aesthetic mode)
            if isAesthetic, let reason = product.aiReasoning, !reason.isEmpty {
                AestheticReasonStrip(text: reason)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
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

// MARK: - Aesthetic Reason Strip

struct AestheticReasonStrip: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.80))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.08))
        )
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
