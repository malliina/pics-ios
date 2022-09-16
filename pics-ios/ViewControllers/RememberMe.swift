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

class RememberMe: NSObject, AWSCognitoIdentityRememberDevice {
    private let log = LoggerFactory.shared.vc(RememberMe.self)
    
    func getRememberDevice(_ rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>) {
        rememberDeviceCompletionSource.set(result: true)
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        
    }
}
