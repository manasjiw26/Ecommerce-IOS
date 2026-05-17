import Foundation

@MainActor
final class CartIntelligenceViewModel: ObservableObject {
    @Published var bundles: [CartBundle] = []
    @Published var resurface: [ResurfaceItem] = []
    @Published var cartCoach: CartCoachResponse? = nil
    @Published var isLoading: Bool = false

    private var deviceId: String { RecommendationEngine.shared.deviceId }
    private var lastSignature: String = ""

    func refresh(cartItems: [CartItem]) async {
        let signature = cartItems
            .sorted { $0.product.id < $1.product.id }
            .map { "\($0.product.id)x\($0.quantity)" }
            .joined(separator: "|")
        if signature == lastSignature { return }
        lastSignature = signature

        isLoading = true
        defer { isLoading = false }

        async let bundleResp = CartIntelligenceService.shared.bundleBuild(cartItems: cartItems, deviceId: deviceId)
        async let resurfaceResp = CartIntelligenceService.shared.resurface(deviceId: deviceId)
        async let coachResp = CartIntelligenceService.shared.cartCoach(cartItems: cartItems)

        do {
            let b = try await bundleResp
            bundles = b.bundles
        } catch {
            bundles = []
        }

        do {
            let r = try await resurfaceResp
            resurface = r.resurface
        } catch {
            resurface = []
        }

        do {
            cartCoach = try await coachResp
        } catch {
            cartCoach = nil
        }
    }
}

