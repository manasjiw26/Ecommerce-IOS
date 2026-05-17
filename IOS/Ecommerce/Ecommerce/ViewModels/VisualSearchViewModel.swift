import SwiftUI
import Combine
import Vision
import CoreImage

@MainActor
class VisualSearchViewModel: ObservableObject {

    enum SearchMode: String {
        case object
        case aesthetic
    }

    // MARK: - Published State
    @Published var searchMode: SearchMode = .object
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

    // Colors extracted from the captured image — drives the palette banner in aesthetic mode
    @Published var detectedColors: [String] = []

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

            let labels       = await self.runVisionAnalysis(on: image)
            let topLabel     = labels.first?.label ?? ""
            // Multi-region color extraction — up to 3 unique dominant tones
            let dominantColors = self.extractDominantColors(image)

            do {
                let response = try await VisualSearchService.shared.performSearch(
                    deviceId: self.deviceId,
                    visionLabels: labels,
                    topLabel: topLabel,
                    image: image,
                    mode: self.searchMode.rawValue,
                    dominantColors: dominantColors
                )
                await MainActor.run {
                    self.visionLabels    = labels
                    self.results         = response.products
                    self.searchLogId     = response.searchLogId
                    self.detectedColors  = dominantColors   // ← drives palette banner
                    self.isLoading       = false
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
        detectedColors = []
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

        // Combine — no duplicates
        var combined = classificationResults
        var seen = Set(combined.map { $0.label })

        for word in textWords where !seen.contains(word) {
            combined.append((label: word, confidence: 0.4))
            seen.insert(word)
        }

        return combined
    }

    // MARK: - Multi-Region Dominant Color Extraction
    // Samples 5 image regions via CIAreaAverage and returns up to 3 unique color names.
    // This gives the backend gate a full palette (e.g. ["beige", "brown", "cream"])
    // instead of a single averaged tone from the entire image.
    nonisolated func extractDominantColors(_ image: UIImage) -> [String] {
        // Downscale to 200×200 for fast CIImage processing
        let targetSize = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let small = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let ciImage = CIImage(image: small) else { return [] }

        let context = CIContext()
        let ext = ciImage.extent  // 0,0,200,200
        let W = ext.width
        let H = ext.height

        // 5 sampling regions (absolute pixel rects)
        let regions: [CGRect] = [
            CGRect(x: 0,       y: 0,        width: W,       height: H * 0.33), // top third
            CGRect(x: 0,       y: H * 0.33, width: W,       height: H * 0.34), // center third
            CGRect(x: 0,       y: H * 0.67, width: W,       height: H * 0.33), // bottom third
            CGRect(x: 0,       y: 0,        width: W * 0.5, height: H),         // left half
            CGRect(x: W * 0.5, y: 0,        width: W * 0.5, height: H)          // right half
        ]

        var colorNames: [String] = []

        for region in regions {
            let cropped = ciImage.cropped(to: region)
            guard
                let filter = CIFilter(name: "CIAreaAverage", parameters: [
                    kCIInputImageKey: cropped,
                    kCIInputExtentKey: CIVector(cgRect: cropped.extent)
                ]),
                let output = filter.outputImage
            else { continue }

            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(
                output,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )

            let r = Float(bitmap[0]) / 255
            let g = Float(bitmap[1]) / 255
            let b = Float(bitmap[2]) / 255
            colorNames.append(rgbToColorName(r: r, g: g, b: b))
        }

        // Deduplicate, preserve order, return max 3
        var seen = Set<String>()
        var unique: [String] = []
        for name in colorNames {
            if seen.insert(name).inserted {
                unique.append(name)
                if unique.count == 3 { break }
            }
        }
        return unique
    }

    // MARK: - RGB → Color Name
    nonisolated private func rgbToColorName(r: Float, g: Float, b: Float) -> String {
        let brightness  = (r + g + b) / 3.0
        let maxC        = max(r, g, b)
        let minC        = min(r, g, b)
        let saturation  = maxC == 0 ? Float(0) : (maxC - minC) / maxC

        // Low saturation → neutral/grey tones
        if saturation < 0.15 {
            if brightness > 0.85 { return "white" }
            if brightness > 0.65 { return "cream" }
            if brightness > 0.45 { return "grey" }
            if brightness > 0.25 { return "charcoal" }
            return "black"
        }

        // Warm low-saturation
        if saturation < 0.35 {
            if r > g && r > b {
                if brightness > 0.7 { return "beige" }
                if brightness > 0.5 { return "tan" }
                return "brown"
            }
            if g > r && g > b { return "sage" }
            return "grey"
        }

        // Saturated colors
        if r > g && r > b {
            if g > b * 1.5        { return "orange" }
            if brightness < 0.35  { return "rust" }
            if brightness > 0.7   { return "blush" }
            return "red"
        }
        if g > r && g > b {
            if brightness < 0.35  { return "forest" }
            return "green"
        }
        if b > r && b > g {
            if r > 0.4            { return "lavender" }
            if brightness < 0.35  { return "navy" }
            return "blue"
        }
        if r > 0.6 && g > 0.6   { return "gold" }
        if r > 0.5 && b > 0.5   { return "blush" }

        return "beige" // fallback
    }
}
