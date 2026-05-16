import SwiftUI
import Combine
import Vision
import CoreImage

@MainActor
class VisualSearchViewModel: ObservableObject {

    // MARK: - Published State
    @Published var isLoading: Bool = false
    @Published var capturedImage: UIImage? = nil
    @Published var visionLabels: [(label: String, confidence: Float)] = []
    @Published var results: [Product] = []
    @Published var showResults: Bool = false
    @Published var showSourceDialog: Bool = false
    @Published var showCamera: Bool = false
    @Published var showPhotoLibrary: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var permissionMessage: String = ""
    @Published var searchLogId: String? = nil

    // Feedback tracking — productId → true/false after user taps thumb
    @Published var feedbackGiven: [Int: Bool] = [:]

    // MARK: - Device ID (reuses existing key from RecommendationEngine)
    private let deviceId: String = {
        let key = "UserDeviceId"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }()

    // MARK: - Entry Point: image was selected
    func handleImageSelected(_ image: UIImage) {
        capturedImage = image
        isLoading = true
        showResults = true
        feedbackGiven = [:]

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let labels = await self.runVisionAnalysis(on: image)
            let topLabel = labels.first?.label ?? ""

            do {
                let response = try await VisualSearchService.shared.performSearch(
                    deviceId: self.deviceId,
                    visionLabels: labels,
                    topLabel: topLabel,
                    image: image          // ← sends base64 for CLIP matching
                )
                await MainActor.run {
                    self.visionLabels = labels
                    self.results     = response.products
                    self.searchLogId = response.searchLogId
                    self.isLoading   = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    // MARK: - Feedback
    func submitFeedback(productId: Int, wasRelevant: Bool) {
        feedbackGiven[productId] = wasRelevant
        Task {
            await VisualSearchService.shared.submitFeedback(
                deviceId: deviceId,
                searchLogId: searchLogId,
                productId: productId,
                wasRelevant: wasRelevant
            )
        }
    }

    // MARK: - Reset
    func reset() {
        capturedImage  = nil
        visionLabels   = []
        results        = []
        showResults    = false
        searchLogId    = nil
        isLoading      = false
        feedbackGiven  = [:]
    }

    // MARK: - Vision Analysis (runs on detached background task)
    nonisolated func runVisionAnalysis(on image: UIImage) async -> [(label: String, confidence: Float)] {
        guard let cgImage = image.cgImage else { return [] }

        var classificationResults: [(label: String, confidence: Float)] = []
        var textWords: [String] = []

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let classifyReq = VNClassifyImageRequest()
        let textReq     = VNRecognizeTextRequest()
        textReq.recognitionLevel = .fast

        try? handler.perform([classifyReq, textReq])

        // Top 15 classification labels (no threshold filter)
        if let obs = classifyReq.results {
            classificationResults = obs
                .sorted { $0.confidence > $1.confidence }
                .prefix(15)
                .map { (label: $0.identifier.lowercased(), confidence: $0.confidence) }
        }

        // Text recognition — individual words >= 4 chars, no spaces
        if let obs = textReq.results {
            textWords = obs
                .compactMap { $0.topCandidates(1).first?.string }
                .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
                .filter { $0.count >= 4 }
                .map { $0.lowercased() }
        }

        // Dominant colour
        let colorLabel = dominantColorName(from: image)

        // Combine — no duplicates
        var combined = classificationResults
        var seen = Set(combined.map { $0.label })

        for word in textWords where !seen.contains(word) {
            combined.append((label: word, confidence: 0.4))
            seen.insert(word)
        }
        if let color = colorLabel, !seen.contains(color) {
            combined.append((label: color, confidence: 0.6))
        }

        return combined
    }

    // MARK: - Dominant Colour via CIAreaAverage
    nonisolated private func dominantColorName(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let context = CIContext()

        let ext = ciImage.extent
        let scaled = ciImage.transformed(
            by: CGAffineTransform(scaleX: 50 / ext.width, y: 50 / ext.height)
        )

        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: scaled,
                kCIInputExtentKey: CIVector(cgRect: scaled.extent)
            ]),
            let output = filter.outputImage
        else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255
        let g = Double(bitmap[1]) / 255
        let b = Double(bitmap[2]) / 255
        return colorName(r: r, g: g, b: b)
    }

    nonisolated private func colorName(r: Double, g: Double, b: Double) -> String {
        let br = (r + g + b) / 3
        if br < 0.15 { return "black" }
        if br > 0.85 { return "white" }
        if r > 0.6 && g < 0.4 && b < 0.4 { return "red" }
        if r > 0.6 && g > 0.45 && b < 0.35 { return "orange" }
        if r > 0.6 && g > 0.6 && b < 0.3  { return "yellow" }
        if g > 0.55 && r < 0.45 && b < 0.45 { return "green" }
        if b > 0.55 && r < 0.45 && g < 0.45 { return "blue" }
        if r > 0.5 && b > 0.5 && g < 0.4   { return "purple" }
        if r > 0.7 && g > 0.5 && b > 0.5   { return "pink" }
        if br > 0.55 && r > g && r > b      { return "beige" }
        return br > 0.5 ? "light gray" : "dark gray"
    }
}
