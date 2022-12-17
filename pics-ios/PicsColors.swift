import Foundation
import UIKit
import SwiftUI

class PicsColors {
    static let shared = PicsColors()
    private static let divisor: CGFloat = 255.0
    static let blue = colorFor(red: 0, green: 122, blue: 255)
    static let tealBlue = colorFor(red: 90, green: 200, blue: 250)
    static let uiLight = colorFor(red: 239, green: 239, blue: 244)
    static let light = Color(uiLight)
    static let uiAlmostLight = colorFor(red: 220, green: 220, blue: 225)
    let almostLight = Color(uiAlmostLight)
    static let blackish = colorFor(red: 50, green: 50, blue: 50)
    static let uiAlmostBlack = colorFor(red: 20, green: 20, blue: 20)
    let almostBlack = Color(uiAlmostBlack)
    static let uiLightBackground = uiLight
    let lightBackground = light
    static let uiBackground = UIColor.black
    let background = Color(uiBackground)
    static let inputBackground = blackish
    let inputBackground2 = Color(inputBackground)
    static let inputText: UIColor = .white
    static let placeholder = UIColor.lightText
    var placeholder2: Color { almostLight }
    static let blueish = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
    let blueish2 = Color(blueish)
    static let buttonText = blueish
    
    static func colorFor(red: Int, green: Int, blue: Int) -> UIColor {
        UIColor(red: CGFloat(red) / PicsColors.divisor, green: CGFloat(green) / PicsColors.divisor, blue: CGFloat(blue) / PicsColors.divisor, alpha: 1.0)
    }
}

extension View {
    var color: PicsColors { PicsColors() }
}
