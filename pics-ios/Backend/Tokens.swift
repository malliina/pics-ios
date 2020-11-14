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
    let username: Username
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
    
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)!
    
    func retrieveUserInfo(cancellationToken: AWSCancellationTokenSource? = nil) -> Single<UserInfo> {
        log.info("Retrieving token...")
        guard let user = pool.currentUser() else { return Single.error(AppError.simple("Unknown user.")) }
        return Single<UserInfo>.create { (single) -> Disposable in
            user.getSession().continueWith(block: { (task) -> Any? in
                if let error = task.error as NSError? {
                    let appError = error.localizedDescription == AppError.noInternetMessage ? AppError.noInternet(error) : AppError.tokenError(error)
                    self.log.warn("Failed to get session with \(error)")
                    single(.error(appError))
                } else {
                    if let accessToken = task.result?.accessToken {
                        //                log.info("Got token \(accessToken.tokenString)")
                        self.delegates.forEach { $0.onAccessToken(accessToken) }
                        if let username = user.username {
                            single(.success(UserInfo(username: Username(username), token: accessToken)))
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
