import SwiftUI

struct BagIntelligenceView: View {
    let coach: CartCoachResponse?
    let resurface: ResurfaceResponse?
    let occasion: Occasion?
    let coachError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let occasion {
                NavigationLink(destination: OccasionSuggestionsView(occasion: occasion)) {
                    OccasionCardView(occasion: occasion)
                }
                .buttonStyle(.plain)
            }

            if let resurface = resurface, let nudge = resurface.resurface.first {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    Text(nudge.reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }

            if let coach {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Bag Coach")
                            .font(.headline)
                        Spacer()
                        Text("\(coach.score)")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    if let banner = coach.bannerInsight, !banner.isEmpty {
                        Text(banner)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(coach.headline)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let next = coach.nextTier, let pct = coach.progressPercentage {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: Double(pct), total: 100)
                                .tint(.primary)
                            Text("Add $\(String(format: "%.2f", next.remaining)) to unlock \(next.label).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if let coachError, !coachError.isEmpty {
                Text(coachError)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

