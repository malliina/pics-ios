//
//  PicView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19.4.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import SwiftUI

struct PicView: View {
    private let log = LoggerFactory.shared.vc(PicView.self)
    let pic: Picture
    let isPrivate: Bool
    
    let smalls: DataCache
    let larges: DataCache
    var backgroundColor: Color { isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var downloader: Downloader { Downloader.shared }
    @State var data: Data? = nil
    
    @MainActor
    func loadImage() async {
        let meta = pic.meta
        let key = meta.key
        if let large = larges.search(key: key) {
            data = large
        } else {
            data = smalls.search(key: key)
            do {
                if data == nil {
                    let smallResult = try await downloader.downloadAsync(url: meta.small)
                    data = smallResult
                }
                let result = try await downloader.downloadAsync(url: meta.large)
                data = result
            } catch let error {
                log.error("Failed to download image \(error)")
            }
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .edgesIgnoringSafeArea(.all)
            if let data = data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().task {
                    await loadImage()
                }
            }
        }
    }
}

struct PicView_Previews: PreviewProvider {
//    let pic = UIImage(named: "AppIcon")
    static var previews: some View {
//        PicView()
        Text("Todo")
    }
}
