//
//  Tokens.swift
//  pics-ios
//
//  Created by Michael Skogberg on 23/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

protocol TokenDelegate {
    func onAccessToken(_ token: AWSCognitoIdentityUserSessionToken)
}

class Tokens {
    private let log = LoggerFactory.shared.system(Tokens.self)
    
    static let shared = Tokens()
    
    private var delegates: [TokenDelegate] = []
    
    func addDelegate(_ d: TokenDelegate) {
        delegates.append(d)
    }
    
    func clearDelegates() {
        delegates = []
    }
    
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    
    func retrieve(onToken: @escaping (AWSCognitoIdentityUserSessionToken) -> Void,
                  onError: @escaping (AppError) -> Void,
                  cancellationToken: AWSCancellationToken?) {
        log.info("Retrieving token...")
        let user = pool.currentUser() ?? pool.getUser()
        user.getSession().continueWith(block: { (task) -> Any? in
            self.process(task: task, onToken: onToken, onError: onError)
            return nil
        }, cancellationToken: cancellationToken)
    }
    
    private func process(task: AWSTask<AWSCognitoIdentityUserSession>,
                         onToken: (AWSCognitoIdentityUserSessionToken) -> Void,
                         onError: @escaping (AppError) -> Void) {
        if let error = task.error as NSError? {
            log.warn("Failed to get session with \(error)")
            onError(.tokenError(error))
        } else {
            if let accessToken = task.result?.accessToken {
//                log.info("Got token \(accessToken.tokenString)")
                onToken(accessToken)
                delegates.forEach { $0.onAccessToken(accessToken) }
            } else {
                log.warn("Missing access token in session")
            }
        }
    }
}
