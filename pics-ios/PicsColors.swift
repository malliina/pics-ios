import Foundation
import UIKit
import SwiftUI

class PicsColors {
    private static let divisor: CGFloat = 255.0
    static let blue = colorFor(red: 0, green: 122, blue: 255)
    static let tealBlue = colorFor(red: 90, green: 200, blue: 250)
    static let uiLight = colorFor(red: 239, green: 239, blue: 244)
    static let light = Color(uiLight)
    static let uiAlmostLight = colorFor(red: 220, green: 220, blue: 225)
    static let almostLight = Color(uiAlmostLight)
    static let blackish = colorFor(red: 50, green: 50, blue: 50)
    static let uiAlmostBlack = colorFor(red: 20, green: 20, blue: 20)
    static let almostBlack = Color(uiAlmostBlack)
    static let uiLightBackground = uiLight
    static let lightBackground = light
    static let uiBackground = UIColor.black
    static let background = Color(uiBackground)
    static let inputBackground = blackish
    static let inputBackground2 = Color(inputBackground)
    static let inputText: UIColor = .white
    static let placeholder = UIColor.lightText
    static let placeholder2 = almostLight
    static let blueish = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
    static let blueish2 = Color(blueish)
    static let buttonText = blueish
    
    static func colorFor(red: Int, green: Int, blue: Int) -> UIColor {
        UIColor(red: CGFloat(red) / PicsColors.divisor, green: CGFloat(green) / PicsColors.divisor, blue: CGFloat(blue) / PicsColors.divisor, alpha: 1.0)
    }
}
