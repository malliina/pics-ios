import Foundation
import SwiftUI

struct OneLinerView: View {
  let text: String

  var body: some View {
    Text(text).padding()
  }
}

struct OneLinerView_Previews: PreviewProvider {
  static var previews: some View {
    ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
      OneLinerView(text: "Hello there, this is a one-liner message view and nothing else.")
        .previewDevice(PreviewDevice(rawValue: deviceName))
        .previewDisplayName(deviceName)
    }
  }
}
