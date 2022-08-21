//
//  CachedImage.swift
//  pics-ios
//
//  Created by Michael Skogberg on 6.8.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI

struct CachedImage: View {
    private static let logger = LoggerFactory.shared.pics(CachedImage.self)
    var log: Logger { CachedImage.logger }
    
    let pic: Picture
    let size: CGSize
    
    var localStorage: LocalPics { LocalPics.shared }
    
    @State var data: Data? = nil
    
    @MainActor
    func loadImage() async {
        data = await picData()
    }
    
    func picData() async -> Data? {
        let key = pic.meta.key
        log.info("Loading \(pic.meta.key)...")
        if let cache = pic.smallData {
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
            let _ = localStorage.saveSmall(data: data, key: pic.meta.key)
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
