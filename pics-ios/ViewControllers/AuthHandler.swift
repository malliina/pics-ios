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

class AuthHandler: NSObject, AWSCognitoIdentityInteractiveAuthenticationDelegate {
    let log = LoggerFactory.shared.vc(AuthHandler.self)
    
    let picsVc: UINavigationController
    let authVc: AuthVC
    let newPassVc: NewPassVC
    let rememberMe: RememberMe
    var active: UIViewController
    
    let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
        let flow = UICollectionViewFlowLayout()
        flow.itemSize = CGSize(width: PicsVC.preferredItemSize, height: PicsVC.preferredItemSize)
        let pics = PicsVC()
        picsVc = UINavigationController(rootViewController: pics)
//        picsVc = PicsVC.build()
        authVc = AuthVC(root: pics)
        newPassVc = NewPassVC(root: pics)
        rememberMe = RememberMe()
        active = picsVc
        super.init()
        pool.delegate = self
    }
    
    static func configure(window: UIWindow) throws -> AuthHandler {
        let conf = try CognitoConf.read()
        let serviceConfiguration = AWSServiceConfiguration(region: .EUWest1, credentialsProvider: nil)
        // create pool configuration
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: conf.clientId,
                                                                        clientSecret: nil,
                                                                        poolId: conf.userPoolId)
        // initialize user pool client
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: poolConfiguration, forKey: AuthVC.PoolKey)
        return AuthHandler(window: window)
    }
    
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        log.info("Start authentication flow")
        present(authVc, from: picsVc)
        return authVc
    }
    
    func startNewPasswordRequired() -> AWSCognitoIdentityNewPasswordRequired {
        log.info("Starting new password flow")
        present(newPassVc, from: picsVc)
        return newPassVc
    }
    
    func present(_ dest: UIViewController, from: UIViewController) {
        DispatchQueue.main.async {
            let navCtrl = UINavigationController(rootViewController: dest)
            navCtrl.navigationBar.barStyle = .black
            navCtrl.navigationBar.prefersLargeTitles = true
//            self.log.info("Presenting \(navCtrl) from \(from)")
//            self.window.rootViewController?.present(navCtrl, animated: true, completion: nil)
            from.present(navCtrl, animated: true, completion: nil)
        }
    }
    
    func startRememberDevice() -> AWSCognitoIdentityRememberDevice {
        log.info("Starting remember device flow")
        return rememberMe
    }
}
