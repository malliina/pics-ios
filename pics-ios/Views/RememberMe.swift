import AWSCognitoIdentityProvider
import Foundation
import UIKit

class RememberMe: NSObject, AWSCognitoIdentityRememberDevice {
  private let log = LoggerFactory.shared.vc(RememberMe.self)

  func getRememberDevice(_ rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>) {
    rememberDeviceCompletionSource.set(result: true)
  }

  func didCompleteStepWithError(_ error: Error?) {

  }
}
