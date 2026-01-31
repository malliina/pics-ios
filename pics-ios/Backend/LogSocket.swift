import AWSCognitoIdentityProvider
import Foundation

class LogSocket {
  private let log = LoggerFactory.shared.network(PicsSocket.self)
  private let socket: WebSocket

  init(baseURL: URL, authValue: String) {
    let headers = [
      HttpClient.authorization: authValue,
      HttpClient.accept: HttpClient.json,
    ]
    socket = WebSocket(baseURL: baseURL, headers: headers)
  }

  func reconnect() {
    socket.connect()
  }

  func send(message: String) async throws {
    try await socket.send(message: message)
  }
}
