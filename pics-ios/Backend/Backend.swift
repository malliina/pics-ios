import AWSCognitoIdentityProvider
import Foundation

class Backend {
  static let shared = Backend(EnvConf.shared.baseUrl)
  private let log = LoggerFactory.shared.system(Backend.self)
  let library: PicsLibrary
  let socket: PicsSocket
  let logs: LogsHttpClient
  
  private var cancellables: [Task<(), Never>] = []

  init(_ baseUrl: URL) {
    let http = PicsHttpClient(accessToken: nil)
    self.library = PicsLibrary(http: http)
    self.socket = PicsSocket(authValue: nil)
    self.logs = LogsHttpClient(baseUrl: EnvConf.shared.logsUrl, client: http)
  }

  func prepare() async {
    let logsListener = Task {
      await logs.listen()
    }
    cancellables = [ logsListener ]
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
