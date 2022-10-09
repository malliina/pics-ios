import Foundation
import AWSCognitoIdentityProvider

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
    lazy var poolOpt = AWSCognitoIdentityUserPool(forKey: CognitoConf.PoolKey)
    var pool: AWSCognitoIdentityUserPool { poolOpt! }
    
    private var delegates: [TokenDelegate] = []
    
    func addDelegate(_ d: TokenDelegate) {
        delegates.append(d)
    }
    
    func clearDelegates() {
        delegates = []
    }
    
    func retrieveUserInfoAsync(cancellationToken: AWSCancellationTokenSource? = nil) async throws -> UserInfo {
//        log.info("Retrieving token...")
        
        return try await withCheckedThrowingContinuation { cont in
            guard let user = poolOpt?.currentUser() else { return cont.resume(throwing: AppError.simple("Unknown user.")) }
            user.getSession().continueWith( block: { (task) in
                if let error = task.error as NSError? {
                    let appError = error.localizedDescription == AppError.noInternetMessage ? AppError.noInternet(error) : AppError.tokenError(error)
                    self.log.warn("Failed to get session with \(error)")
                    cont.resume(throwing: appError)
                } else {
                    if let accessToken = task.result?.accessToken {
//                        self.log.info("Got token \(accessToken.tokenString)")
                        self.delegates.forEach { $0.onAccessToken(accessToken) }
                        if let username = user.username {
                            cont.resume(returning: UserInfo(username: Username(username), token: accessToken))
                        } else {
                            cont.resume(throwing: AppError.simple("Missing username."))
                        }
                    } else {
                        self.log.warn("Missing access token in session")
                        cont.resume(throwing: AppError.simple("Missing access token in session"))
                    }
                }
                return nil
            }, cancellationToken: cancellationToken?.token)
        }
    }
}
