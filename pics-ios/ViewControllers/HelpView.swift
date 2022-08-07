//
//  HelpView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 18.4.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import SwiftUI

struct HelpView: View {
    var isPrivate: Bool
//    var dismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    var textColor: UIColor { isPrivate ? .lightText : .darkText }
    var titleColor: UIColor { isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    var backgroundColor: UIColor { isPrivate ? PicsColors.background : PicsColors.lightBackground }
    let bundleMeta = Bundle.main.infoDictionary
    
    var body: some View {
        ZStack {
            // iPad shows wrong color at sheet edges without this
            Color(backgroundColor)
                .edgesIgnoringSafeArea(.all)
            VStack {
                Text("Developed by Michael Skogberg.")
                    .foregroundColor(Color(textColor))
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                Text("You can reach me at info@skogberglabs.com. To report objectionable images or copyright violations: Tap the image, then tap it again to open the navigation bar and select an appropriate action from the action button. Abusive images will be removed within 24 hours.")
                    .foregroundColor(Color(textColor))
                    .multilineTextAlignment(.center)
                if let appVersion = bundleMeta?["CFBundleShortVersionString"] as? String, let buildId = bundleMeta?["CFBundleVersion"] as? String {
                    Spacer()
                    Text("Version \(appVersion) build \(buildId)")
                        .foregroundColor(Color(textColor))
                        .font(.system(size: 14))
                }
            }
            .navigationTitle("Information")
            .navigationBarTitleTextColor(titleColor)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .padding()
        }
    }
}

struct HelpTextView: View {
    var body: some View {
        Text("Hej").background(Color.red)
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

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            HelpView(isPrivate: true)
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
