//
//  Tokens.swift
//  pics-ios
//
//  Created by Michael Skogberg on 23/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

class Tokens {
    private let log = LoggerFactory.shared.system(Tokens.self)
    
    static let shared = Tokens()
    
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    
    func retrieveToken(onToken: @escaping (AWSCognitoIdentityUserSessionToken) -> Void) {
        retrieve(onToken: onToken, cancellationToken: nil)
    }
    
    func retrieve(onToken: @escaping (AWSCognitoIdentityUserSessionToken) -> Void, cancellationToken: AWSCancellationToken?) {
        log.info("Retrieving token...")
        let user = pool.currentUser() ?? pool.getUser()
        user.getSession().continueWith(block: { (task) -> Any? in
            self.log.info("Got session")
            if let error = task.error as NSError? {
                self.log.warn("Failed to get session with \(error)")
            } else {
                if let accessToken = task.result?.accessToken {
                    self.log.info("Got token \(accessToken.tokenString)")
                    onToken(accessToken)
                } else {
                    self.log.warn("Missing action token in session")
                }
            }
            return nil
        }, cancellationToken: cancellationToken)
    }
}
