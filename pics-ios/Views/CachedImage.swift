//
//  CachedImage.swift
//  pics-ios
//
//  Created by Michael Skogberg on 6.8.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI

class ImageData: ObservableObject {
    private let log = LoggerFactory.shared.pics(ImageData.self)
    @Published var image: Data? = nil
    
    var localStorage: LocalPics { LocalPics.shared }
    
    let pic: Picture
    
    init(pic: Picture) {
        self.pic = pic
        Task {
            await load()
        }
    }
    
    func load() async {
        let data = await picData()
        pic.smallData = data
        DispatchQueue.main.async {
            self.image = data
        }
    }
    
    func picData() async -> Data {
        let key = pic.meta.key
        if let uiImage = pic.preferred,
            let imageData = uiImage.jpegData(compressionQuality: 1) {
            log.info("Using local image for '\(key)'.")
            return imageData
        }
        if let localData = localStorage.readSmall(key: key) {
            log.info("Using local pic for '\(key)'.")
            return localData
        }
        let data = await Downloader.shared.downloadAsync(url: pic.meta.small)
        let _ = localStorage.saveSmall(data: data, key: pic.meta.key)
        return data
    }
}

struct CachedImage: View {
    @EnvironmentObject var imageData: ImageData
    
    let size: CGSize

    var image: Data? {
        imageData.image
    }
    
    var body: some View {
        if let image = image, let uiImage = UIImage(data: image) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            ProgressView().frame(width: size.width, height: size.height)
        }
    }
}
