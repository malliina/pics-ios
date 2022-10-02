//
//  CachedImage.swift
//  pics-ios
//
//  Created by Michael Skogberg on 6.8.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI

class DataCache {
    static func small() -> DataCache { DataCache() }
    static func large() -> DataCache { DataCache() }
    
    private var cache: [ClientKey: Data] = [:]
    
    func search(key: ClientKey) -> Data? {
        cache[key]
    }
    
    func put(key: ClientKey, data: Data) {
        cache[key] = data
    }
}

struct CachedImage: View {
    private static let logger = LoggerFactory.shared.pics(CachedImage.self)
    var log: Logger { CachedImage.logger }
    
    var pic: Picture
    let size: CGSize
    let cache: DataCache
    
    var localStorage: LocalPics { LocalPics.shared }
    
    @State var data: Data? = nil
    
    @MainActor
    func loadImage() async {
        guard data == nil else { return }
        data = await picData()
        if let data = data {
            cache.put(key: pic.meta.key, data: data)
        }
    }
    
    func picData() async -> Data? {
        let key = pic.meta.key
        if let cache = cache.search(key: key) {
            return cache
        }
        if let uiImage = pic.preferred,
            let imageData = uiImage.jpegData(compressionQuality: 1) {
            log.info("Using local image for '\(key)'.")
            return imageData
        }
        if let localData = localStorage.readSmall(key: key) {
            return localData
        }
        let url = pic.meta.small
        do {
            let data = try await Downloader.shared.download(url: url)
            let _ = localStorage.saveSmall(data: data, key: key)
            return data
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
