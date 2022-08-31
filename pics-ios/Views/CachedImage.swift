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
    static let small = DataCache()
    static let large = DataCache()
    
    private var cache: [ClientKey: Data] = [:]
    
    func search(key: ClientKey) -> Data? { cache[key] }
    
    func put(key: ClientKey, data: Data) { cache[key] = data }
}

struct CachedImage: View {
    private static let logger = LoggerFactory.shared.pics(CachedImage.self)
    var log: Logger { CachedImage.logger }
    
    var pic: Picture
    let size: CGSize
    
    var localStorage: LocalPics { LocalPics.shared }
    var cache: DataCache { DataCache.small }
    
    @State var data: Data? = nil
    
    @MainActor
    func loadImage() async {
        data = await picData()
        if let data = data {
            DataCache.small.put(key: pic.meta.key, data: data)
        }
    }
    
    func picData() async -> Data? {
        let key = pic.meta.key
//        log.info("Loading \(pic.meta.key)...")
        if let cache = cache.search(key: key) {
            return cache
        }
        if let uiImage = pic.preferred,
            let imageData = uiImage.jpegData(compressionQuality: 1) {
            log.info("Using local image for '\(key)'.")
            return imageData
        }
        if let localData = localStorage.readSmall(key: key) {
            log.info("Using local pic for '\(key)'.")
            return localData
        }
        if let data = try? await Downloader.shared.downloadAsync(url: pic.meta.small) {
            let _ = localStorage.saveSmall(data: data, key: key)
            return data
        } else {
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
            ProgressView().frame(width: size.width, height: size.height).task {
                await loadImage()
            }
        }
    }
}
