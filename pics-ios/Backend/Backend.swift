import AWSCognitoIdentityProvider
import Foundation

class Backend {
  static let shared = Backend(EnvConf.shared.baseUrl)
  private let log = LoggerFactory.shared.system(Backend.self)
  let library: PicsLibrary
  let socket: PicsSocket

  init(_ baseUrl: URL) {
    self.library = PicsLibrary(http: PicsHttpClient(accessToken: nil))
    self.socket = PicsSocket(authValue: nil)
  }

  func updateToken(new token: AWSCognitoIdentityUserSessionToken?) {
    library.http.updateToken(token: token)
    socket.updateAuthHeader(with: authValue(token: token))
    Downloader.shared.updateToken(token: token)
  }

  private func authValue(token: AWSCognitoIdentityUserSessionToken?) -> String? {
    guard let token = token else { return nil }
    return PicsHttpClient.authValueFor(forToken: token)
  }
}
