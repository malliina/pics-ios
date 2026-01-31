import SwiftUI

class PicsPreviews {
  static let shared = PicsPreviews()

  let devices = ["iPhone 13 mini", "iPad Pro (11-inch) (4th generation)"]
}

protocol PicsPreviewProvider: PreviewProvider {
  associatedtype Preview: View
  static var preview: Preview { get }
}

extension PicsPreviewProvider {
  static var previews: some View {
    ForEach(PicsPreviews.shared.devices, id: \.self) { deviceName in
      Group {
        preview
      }
      .previewDevice(PreviewDevice(rawValue: deviceName))
      .previewDisplayName(deviceName)
    }
  }
}
