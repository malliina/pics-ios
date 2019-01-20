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

struct UserInfo {
    let username: String
    let token: AWSCognitoIdentityUserSessionToken
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
    
    func retrieve(cancellationToken: AWSCancellationTokenSource?) -> Single<AWSCognitoIdentityUserSessionToken> {
        return retrieveUserInfo(cancellationToken: cancellationToken).map { ui in ui.token }
    }
    
    func retrieveUserInfo(cancellationToken: AWSCancellationTokenSource? = nil) -> Single<UserInfo> {
        log.info("Retrieving token...")
        guard let user = pool.currentUser() else { return Single.error(AppError.simple("Unknown user.")) }
        return Single<UserInfo>.create { (single) -> Disposable in
            user.getSession().continueWith(block: { (task) -> Any? in
                if let error = task.error as NSError? {
                    self.log.warn("Failed to get session with \(error)")
                    single(.error(AppError.tokenError(error)))
                } else {
                    if let accessToken = task.result?.accessToken {
                        //                log.info("Got token \(accessToken.tokenString)")
                        self.delegates.forEach { $0.onAccessToken(accessToken) }
                        if let username = user.username {
                            single(.success(UserInfo(username: username, token: accessToken)))
                        } else {
                            single(.error(AppError.simple("Missing username.")))
                        }
                    } else {
                        self.log.warn("Missing access token in session")
                        single(.error(AppError.simple("Missing access token in session")))
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
