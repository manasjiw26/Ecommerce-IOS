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
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }

            if let coach {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "sparkles")
                        Text("Bag Coach")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(coach.score)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }

                    if let banner = coach.bannerInsight, !banner.isEmpty {
                        Text(banner)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(coach.headline)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let next = coach.nextTier, let pct = coach.progressPercentage {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: Double(pct), total: 100)
                                .tint(.primary)
                            Text("Add $\(String(format: "%.2f", next.remaining)) to unlock \(next.label).")
                                .font(.caption2)
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
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
