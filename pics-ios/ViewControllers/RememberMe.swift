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
