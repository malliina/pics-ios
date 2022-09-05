//
//  AuthVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class AuthVC: BaseVC {
    static let PoolKey = "PicsPool"
    let log = LoggerFactory.shared.vc(AuthVC.self)

    let welcomeText = PicsLabel.build(text: "Log in to your personal gallery. Images are always public.", alignment: .center, numberOfLines: 0)
    let username = PicsTextField.with(placeholder: "Username")
    let password = PicsTextField.with(placeholder: "Password", isPassword: true)
    let loginButton = PicsButton.create(title: "Log in")
    let signupButton = PicsButton.create(title: "Sign up")
    let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    let marginSmall = 8
    let marginLarge = 24
    let maxWidth = 500
    
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
}

class RememberMe: NSObject, AWSCognitoIdentityRememberDevice {
    private let log = LoggerFactory.shared.vc(RememberMe.self)
    
    func getRememberDevice(_ rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>) {
        rememberDeviceCompletionSource.set(result: true)
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        
    }
}
