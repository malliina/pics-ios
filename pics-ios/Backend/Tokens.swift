//
//  Tokens.swift
//  pics-ios
//
//  Created by Michael Skogberg on 23/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider
import RxSwift
import RxCocoa

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
    
    func retrieve(cancellationToken: AWSCancellationTokenSource?) -> Observable<AWSCognitoIdentityUserSessionToken> {
        log.info("Retrieving token...")
        let user = pool.currentUser() ?? pool.getUser()
        return Observable<AWSCognitoIdentityUserSessionToken>.create { (subscriber) -> Disposable in
            user.getSession().continueWith(block: { (task) -> Any? in
                if let error = task.error as NSError? {
                    self.log.warn("Failed to get session with \(error)")
                    subscriber.onError(AppError.tokenError(error))
                } else {
                    if let accessToken = task.result?.accessToken {
                        //                log.info("Got token \(accessToken.tokenString)")
                        self.delegates.forEach { $0.onAccessToken(accessToken) }
                        subscriber.onNext(accessToken)
                        subscriber.onCompleted()
                    } else {
                        self.log.warn("Missing access token in session")
                        subscriber.onError(AppError.simple("Missing access token in session"))
                    }
                }
                return nil
            }, cancellationToken: cancellationToken?.token)
            return Disposables.create {
                cancellationToken?.cancel()
            }
        }
    }
}
