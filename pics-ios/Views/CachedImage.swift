import Foundation
import SwiftUI

class DataCache {
    static func small() -> DataCache { DataCache() }
    static func large() -> DataCache { DataCache() }
    
    private let q = DispatchQueue(label: "com.skogberglabs.pics", attributes: .concurrent)
    private let l = NSLock()
    private var cache: [ClientKey: Data] = [:]
    
    func search(key: ClientKey) -> Data? {
        var data: Data? = nil
        l.lock()
        data = cache[key]
        l.unlock()
        return data
    }
    
    func put(key: ClientKey, data: Data) {
        l.lock()
        cache[key] = data
        l.unlock()
    }
}

/// Thumbnail sized image view used in gallery. For full-size image view, see PicView
struct CachedImage: View {
    private static let logger = LoggerFactory.shared.pics(CachedImage.self)
    var log: Logger { CachedImage.logger }
    
    let meta: PicMeta
    let size: CGSize
    let cache: DataCache
    
    var localStorage: LocalPics { LocalPics.shared }
    
    @State var data: Data? = nil
    
    @MainActor
    func loadImage() async {
        guard data == nil else { return }
        data = await picData()
        if let data = data {
            cache.put(key: meta.key, data: data)
        }
    }
    
    func picData() async -> Data? {
        let key = meta.key
        if let cache = cache.search(key: key) {
            return cache
        }
        if let localData = localStorage.readSmall(key: key) {
            return localData
        }
        let url = meta.small
        do {
            if url.isFileURL {
                return try Data(contentsOf: url)
            } else {
                let data = try await Downloader.shared.download(url: url)
                let _ = localStorage.saveSmall(data: data, key: key)
                return data
            }
        } catch let error {
            log.error("Failed to download \(url). \(error)")
            return nil
        }
    }
    
    var body: some View {
        if let image = data, let uiImage = UIImage(data: image) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            ProgressView().frame(width: size.width, height: size.height).onAppear {
                // Not using .task, since it's cancelled when this view disappears
                Task {
                    await loadImage()
                }
            }
        }
    }
}
