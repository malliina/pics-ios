//
//  AuthHandler.swift
//  pics-ios
//
//  Created by Michael Skogberg on 03/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider
import SwiftUI

class AuthHandler: NSObject, AWSCognitoIdentityInteractiveAuthenticationDelegate {
    let log = LoggerFactory.shared.vc(AuthHandler.self)
    
    let picsVc: UINavigationController
    let rememberMe: RememberMe
    let active: UIViewController
    
    private var loginHandler: LoginHandler? = nil
    
    private override init() {
        let nav = UINavigationController()
        let picsViewModel = PicsVM { user in
            nav.navigationBar.barStyle = user != nil ? UIBarStyle.black : .default
        }
        let pics = UIHostingController(rootView: PicsView(viewModel: picsViewModel))
        nav.pushViewController(pics, animated: false)
        picsVc = nav
        rememberMe = RememberMe()
        active = picsVc
        super.init()
        Tokens.shared.pool.delegate = self
    }
    
    static func configure() throws -> AuthHandler {
        let conf = try CognitoConf.read()
        let serviceConfiguration = AWSServiceConfiguration(region: .EUWest1, credentialsProvider: nil)
        // create pool configuration
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: conf.clientId,
                                                                        clientSecret: nil,
                                                                        poolId: conf.userPoolId)
        // initialize user pool client
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: poolConfiguration, forKey: CognitoConf.PoolKey)
        return AuthHandler()
    }
    
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        log.info("Start authentication flow")
        let handler = LoginHandler()
        loginHandler = handler
        let view = NavigationView {
            LoginView(handler: handler)
        }
        presentView(view, from: picsVc)
        return handler
    }
    
    func startNewPasswordRequired() -> AWSCognitoIdentityNewPasswordRequired {
        log.info("Starting new password flow")
        let view = NavigationView {
            NewPassView(handler: loginHandler!)
        }
        presentView(view, from: picsVc)
        return loginHandler!
    }
    
    func presentView<T: View>(_ dest: T, from: UIViewController) {
        DispatchQueue.main.async {
            let host = UIHostingController(rootView: dest)
            from.present(host, animated: true, completion: nil)
        }
    }
    
    func startRememberDevice() -> AWSCognitoIdentityRememberDevice {
        log.info("Starting remember device flow")
        return rememberMe
    }
}
