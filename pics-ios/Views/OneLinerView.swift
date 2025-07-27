import Foundation
import SwiftUI

struct OneLinerView: View {
  let text: String

  var body: some View {
    Text(text).padding()
  }
}

struct OneLinerPreviews: PicsPreviewProvider, PreviewProvider {
  static var preview: some View {
    OneLinerView(text: "Hello there, this is a one-liner message view and nothing else.")
  }
}
