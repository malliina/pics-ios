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
    private static let log = LoggerFactory.shared.pics(CachedImage.self)
    @State var data: Data? = nil
    let pic: Picture
    let size: CGSize
    
    var localStorage: LocalPics { LocalPics.shared }
    
    @MainActor
    func loadImage() async {
        data = await picData()
    }
    
    func picData() async -> Data {
        if let cache = pic.smallData {
            return cache
        }
        let key = pic.meta.key
        if let uiImage = pic.preferred,
            let imageData = uiImage.jpegData(compressionQuality: 1) {
            CachedImage.log.info("Using local image for '\(key)'.")
            return imageData
        }
        if let localData = localStorage.readSmall(key: key) {
            CachedImage.log.info("Using local pic for '\(key)'.")
            return localData
        }
        let data = await Downloader.shared.downloadAsync(url: pic.meta.small)
        let _ = localStorage.saveSmall(data: data, key: pic.meta.key)
        return data
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
