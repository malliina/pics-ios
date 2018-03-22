//
//  Utils.swift
//  pics-ios
//
//  Created by Michael Skogberg on 20/03/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

// https://stackoverflow.com/questions/2658738/the-simplest-way-to-resize-an-uiimage/2658801
extension UIImage {
    func toPixels(_ newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0);
        self.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
