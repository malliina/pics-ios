//
//  PicsView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 15.5.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI

struct PicsView: View {
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                grid(geometry: geometry)
            }
        }
    }
    
    func grid(geometry: GeometryProxy) -> some View {
        let sizeInfo = PicsCell.sizeForItem(minWidthPerItem: PicsVC.preferredItemSize, totalWidth: geometry.size.width)
        let columns: [GridItem] = Array(repeating: .init(.flexible()), count: sizeInfo.itemsPerRow)
        return LazyVGrid(columns: columns) {
            ForEach((0...79), id: \.self) { _ in
                Image(uiImage: UIImage(named: "AppIcon")!).resizable().scaledToFill()
            }
        }.font(.largeTitle)
    }
}

struct PicsView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            PicsView()
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
