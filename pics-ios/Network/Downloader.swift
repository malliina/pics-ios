import AWSCognitoIdentityProvider
import Foundation

enum DownloadResult {
  case data(data: Data)
  case failure(error: Error)
}

class Downloader {
  static let shared = Downloader()
  private let log = LoggerFactory.shared.network(Downloader.self)

  private var requestHeaders: [String: String] = [HttpClient.accept: PicsHttpClient.PicsVersion10]

  func updateToken(token: AWSCognitoIdentityUserSessionToken?) {
    if let token = token {
      self.requestHeaders.updateValue(
        PicsHttpClient.authValueFor(forToken: token), forKey: HttpClient.authorization)
    } else {
      self.requestHeaders.removeValue(forKey: HttpClient.authorization)
    }
  }

  func download(url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    for (key, value) in requestHeaders {
      request.addValue(value, forHTTPHeaderField: key)
    }
    log.info("Submitting download of \(url)")
    let (data, _) = try await URLSession.shared.data(for: request)
    return data
  }
}
