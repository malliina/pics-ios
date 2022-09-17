//
//  EulaVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 28/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

struct EulaView: View {
    @State private var isPresented = true
    @State private var userDisagrees = false
    
    let proceedToApp: () -> Void
    
    var body: some View {
        EmptyView()
        .alert("Terms of Usage", isPresented: $isPresented) {
            Button("I Disagree") {
                isPresented = false
                userDisagrees = true
            }
            Button("I Agree") {
                isPresented = false
                proceedToApp()
            }
        } message: {
            Text("There is no tolerance for objectionable content or abusive users. Violators will be blocked from the app. The developers of this app assume all rights to images added to this app. Images may be added or removed at the discretion of the app developers at any time. You must agree to these terms in order to continue using this app.")
        }
        .alert("Agreement Required", isPresented: $userDisagrees) {
            Button("OK") {
                userDisagrees = false
                isPresented = true
            }
        }
    }
}
