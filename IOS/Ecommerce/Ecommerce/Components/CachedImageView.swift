import SwiftUI
import Combine
import UIKit

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    init() {
        // Enforce caching limits (decaching)
        cache.countLimit = 200 // Max 200 images
        cache.totalCostLimit = 1024 * 1024 * 150 // Max 150 MB
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var urlString: String
    private var task: URLSessionDataTask?
    
    init(urlString: String) {
        self.urlString = urlString
        loadImage()
    }
    
    func loadImage() {
        if let cachedImage = ImageCache.shared.get(forKey: urlString) {
            self.image = cachedImage
            return
        }
        
        // If the URL is already encoded (contains %), use it directly. 
        // Otherwise, add encoding for safety.
        let finalUrlString = urlString.contains("%") ? urlString : (urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
        
        guard let url = URL(string: finalUrlString) else { 
            print("❌ Invalid image URL: \(urlString)")
            return 
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error as NSError? {
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    return // Expected when scrolling
                }
                if error.localizedDescription.lowercased().contains("cancelled") {
                    return // Fallback check
                }
                print("❌ Image Load Error: \(error.localizedDescription) for: \(self?.urlString ?? "")")
                return
            }
            
            if let data = data, let downloadedImage = UIImage(data: data) {
                ImageCache.shared.set(downloadedImage, forKey: self?.urlString ?? "")
                DispatchQueue.main.async {
                    self?.image = downloadedImage
                }
            } else {
                print("⚠️ Failed to convert data to image: \(self?.urlString ?? "")")
            }
        }
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
}

struct CachedImageView<Content: View, Placeholder: View>: View {
    @StateObject private var loader: ImageLoader
    let urlString: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    init(urlString: String, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        _loader = StateObject(wrappedValue: ImageLoader(urlString: urlString))
        self.urlString = urlString
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        ZStack {
            if let uiImage = loader.image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .onAppear {
            if loader.image == nil {
                print("🖼️ Loading image: \(urlString)")
                loader.loadImage()
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }
}
