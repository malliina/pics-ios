import Foundation
import AWSCognitoIdentityProvider

class CognitoDelegate: NSObject, AWSCognitoIdentityInteractiveAuthenticationDelegate {
    let log = LoggerFactory.shared.vc(CognitoDelegate.self)

    let rememberMe: RememberMe = RememberMe()
    let handler: LoginHandler

    let onShowLogin: () -> Void
    let onShowNewPass: () -> Void
    
    init(onShowLogin: @escaping () -> Void, onShowNewPass: @escaping () -> Void) {
        self.handler = LoginHandler()
        self.onShowLogin = onShowLogin
        self.onShowNewPass = onShowNewPass
    }
    
    static func configure() throws {
        let conf = try CognitoConf.read()
        let serviceConfiguration = AWSServiceConfiguration(region: .EUWest1, credentialsProvider: nil)
        // create pool configuration
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: conf.clientId,
                                                                        clientSecret: nil,
                                                                        poolId: conf.userPoolId)
        // initialize user pool client
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: poolConfiguration, forKey: CognitoConf.PoolKey)
    }
    
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        log.info("Start authentication flow")
        onShowLogin()
        return handler
    }
    
    func startNewPasswordRequired() -> AWSCognitoIdentityNewPasswordRequired {
        log.info("Starting new password flow")
        onShowNewPass()
        return handler
    }
    
    
    func startRememberDevice() -> AWSCognitoIdentityRememberDevice {
        log.info("Starting remember device flow")
        return rememberMe
    }
}
