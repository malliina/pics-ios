//
//  PicView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19.4.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import SwiftUI

struct PicView: View {
    let pic: Picture
    let isPrivate: Bool
    
    var smalls: DataCache { DataCache.small }
    var larges: DataCache { DataCache.large }
    var backgroundColor: Color { isPrivate ? PicsColors.background : PicsColors.lightBackground }
    
    @State var data: Data? = nil
    
    @MainActor
    func loadImage() async {
        let key = pic.meta.key
        if let large = larges.search(key: key) {
            data = large
        } else {
            data = smalls.search(key: key)
            if let result = try? await Downloader.shared.downloadAsync(url: pic.meta.large) {
                data = result
            }
        }
    }
    
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            ZStack {
                backgroundColor
                    .edgesIgnoringSafeArea(.all)
                Image(uiImage: uiImage).resizable().scaledToFit().background(backgroundColor)
            }
        } else {
            ProgressView().scaledToFill().task {
                await loadImage()
            }.background(backgroundColor)
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
