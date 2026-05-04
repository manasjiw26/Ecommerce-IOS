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
        
        guard let url = URL(string: urlString) else { return }
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil, let downloadedImage = UIImage(data: data) else {
                return
            }
            
            ImageCache.shared.set(downloadedImage, forKey: self.urlString)
            
            DispatchQueue.main.async {
                self.image = downloadedImage
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
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    init(urlString: String, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        _loader = StateObject(wrappedValue: ImageLoader(urlString: urlString))
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
        .onDisappear {
            loader.cancel() // Cancel network request if it scrolls off screen
        }
    }
}
