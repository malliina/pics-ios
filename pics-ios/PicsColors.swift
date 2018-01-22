//
//  PicsColors.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class PicsColors {
    private static let divisor: CGFloat = 255.0
    static let purple = PicsColors.colorFor(red: 88, green: 86, blue: 214)
    static let blue = PicsColors.colorFor(red: 0, green: 122, blue: 255)
    static let tealBlue = PicsColors.colorFor(red: 90, green: 200, blue: 250)
    static let light = PicsColors.colorFor(red: 239, green: 239, blue: 244)
    static let almostLight = PicsColors.colorFor(red: 220, green: 220, blue: 225)
    static let darkish = PicsColors.colorFor(red: 180, green: 180, blue: 180)
    static let blackish = PicsColors.colorFor(red: 50, green: 50, blue: 50)
    static let almostBlack = PicsColors.colorFor(red: 20, green: 20, blue: 20)
    static let lightBackground = light
    static let background = UIColor.black
//    static let inputBackground = PicsColors.colorFor(red: 206, green: 206, blue: 210)
    static let inputBackground = blackish
//    static let inputBackground = tealBlue
    static let inputText: UIColor = .white
    static let placeholder = UIColor.lightText
    static let buttonText = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
    
    static func colorFor(red: Int, green: Int, blue: Int) -> UIColor {
        return UIColor(red: CGFloat(red) / PicsColors.divisor, green: CGFloat(green) / PicsColors.divisor, blue: CGFloat(blue) / PicsColors.divisor, alpha: 1.0)
    }
}
