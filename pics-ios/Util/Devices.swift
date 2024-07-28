import Foundation
import UIKit

class Devices {
  static var isIpad: Bool {
    let traits = UIScreen.main.traitCollection
    return traits.horizontalSizeClass == .regular && traits.verticalSizeClass == .regular
  }
}
