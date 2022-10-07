//
//  ProfilePopover.swift
//  pics-ios
//
//  Created by Michael Skogberg on 27/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI

protocol ProfileDelegate {
    func onPublic()
    func onPrivate(user: Username)
    func onLogout() async
}

struct ProfilePopoverView: View {
    let log = LoggerFactory.shared.vc(ProfilePopoverView.self)
    
    @Environment(\.dismiss) private var dismiss
    
    let user: Username?
    var isPrivate: Bool { user != nil }
    let delegate: ProfileDelegate
    
    var body: some View {
        List {
            HStack {
                Text("Public gallery")
                Spacer()
                if !isPrivate {
                    Image(systemName: "checkmark").foregroundColor(PicsColors.blueish2)
                }
            }.contentShape(Rectangle()).onTapGesture {
                dismiss()
                delegate.onPublic()
            }
            HStack {
                Text(user?.user ?? "Log in").foregroundColor(user == nil ? PicsColors.blueish2 : PicsColors.almostBlack)
                Spacer()
                if isPrivate {
                    Image(systemName: "checkmark").foregroundColor(PicsColors.blueish2)
                }
            }.contentShape(Rectangle()).onTapGesture {
                Task {
                    do {
                        dismiss()
                        try await Task.sleep(nanoseconds: 500_000_000)
                        let userInfo = try await Tokens.shared.retrieveUserInfoAsync()
                        self.delegate.onPrivate(user: userInfo.username)
                    } catch let error {
                        self.log.error("Failed to retrieve user info. No network? \(error)")
                    }
                }
            }
            if isPrivate {
                HStack {
                    Text("Log out").foregroundColor(.red)
                    Spacer()
                }.contentShape(Rectangle()).onTapGesture {
                    dismiss()
                    Task {
                        await delegate.onLogout()
                    }
                }
            }
        }
    }
}

struct ProfilePopoverView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            ProfilePopoverView(user: nil, delegate: NoopProfileDelegate())
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}

class NoopProfileDelegate: ProfileDelegate {
    func onPublic() {}
    func onPrivate(user: Username) {}
    func onLogout() {}
}
