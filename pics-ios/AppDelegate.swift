import AWSCognitoIdentityProvider
import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
  let log = LoggerFactory.shared.system(AppDelegate.self)

  var transferCompletionHandlers: [String: () -> Void] = [:]

  func application(
    _ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    log.info("Task complete: \(identifier)")
    transferCompletionHandlers[identifier] = completionHandler
    BackgroundTransfers.uploader.setup()
  }
}
