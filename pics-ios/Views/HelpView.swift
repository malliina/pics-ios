import SwiftUI

struct HelpView: View {
  var isPrivate: Bool
  @Environment(\.dismiss) private var dismiss
  var uiTextColor: UIColor { isPrivate ? .lightText : .darkText }
  var textColor: Color { Color(uiTextColor) }
  var titleColor: Color { isPrivate ? color.almostLight : color.almostBlack }
  var backgroundColor: Color { isPrivate ? color.background : color.lightBackground }
  let bundleMeta = Bundle.main.infoDictionary

  var body: some View {
    ZStack {
      // iPad shows wrong color at sheet edges without this
      backgroundColor
        .edgesIgnoringSafeArea(.all)
      VStack {
        Text("Developed by Michael Skogberg.")
          .foregroundColor(textColor)
          .padding(.top, 24)
          .padding(.bottom, 16)
        Text(
          "You can reach me at info@skogberglabs.com. To report objectionable images or copyright violations: Tap the image, then tap it again to open the navigation bar and select an appropriate action from the action button. Abusive images will be removed within 24 hours."
        )
        .foregroundColor(textColor)
        .multilineTextAlignment(.center)
        if let appVersion = bundleMeta?["CFBundleShortVersionString"] as? String,
          let buildId = bundleMeta?["CFBundleVersion"] as? String
        {
          Spacer()
          Text("Version \(appVersion) build \(buildId)")
            .foregroundColor(textColor)
            .font(.system(size: 14))
        }
      }
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Information")
            .font(.headline)
            .foregroundColor(titleColor)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Text("Done").font(.body.bold())
          }
        }
      }
      .padding()
    }
  }
}

extension View {
  /// https://stackoverflow.com/a/66050825
  func navigationBarTitleTextColor(_ color: UIColor) -> some View {
    UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: color]
    UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: color]
    return self
  }
}

struct HelpPreviews: PicsPreviewProvider, PreviewProvider {
  static var preview: some View {
    NavigationView {
      HelpView(isPrivate: true)
    }
    //      NavigationView {
    //        HelpView(isPrivate: false)
    //          .previewDevice(PreviewDevice(rawValue: deviceName))
    //          .previewDisplayName(deviceName)
    //      }
    //    }
  }
}
