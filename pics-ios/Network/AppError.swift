import Foundation

enum AppError: Error {
  case parseError(JsonError)
  case responseFailure(ResponseDetails)
  case networkFailure(RequestFailure)
  case simpleError(ErrorMessage)
  case tokenError(Error)
  case noInternet(Error)

  var describe: String { AppError.stringify(self) }

  static func stringify(_ error: AppError) -> String {
    AppErrorUtil.stringify(error)
  }

  static func simple(_ message: String) -> AppError {
    AppError.simpleError(ErrorMessage(message))
  }

  static let noInternetMessage = "The Internet connection appears to be offline."
}

class AppErrorUtil {
  static func stringify(_ error: AppError) -> String {
    switch error {
    case .parseError(let json):
      switch json {
      case .missing(let key):
        return "Key not found: '\(key)'."
      case .invalid(let key, let actual):
        return "Invalid '\(key)' value: '\(actual)'."
      case .notJson(_):
        return "Invalid response format. Expected JSON."
      }
    case .responseFailure(let details):
      let code = details.code
      switch code {
      case 400:
        return "Bad request: \(details.resource)."
      case 401:
        return "Check your username/password."
      case 404:
        return "Resource not found: \(details.resource)."
      case 406:
        return
          "Please update this app to the latest version to continue. This version is no longer supported."
      default:
        if let message = details.message {
          return "Error code: \(code), message: \(message)"
        } else {
          return "Error code: \(code)."
        }
      }
    case .networkFailure(_):
      return "A network error occurred."
    case .tokenError(_):
      return "A network error occurred."
    case .simpleError(let message):
      return message.message
    case .noInternet(_):
      return AppError.noInternetMessage
    }

  }

  static func stringifyDetailed(_ error: AppError) -> String {
    switch error {
    case .networkFailure(let request):
      return "Unable to connect to \(request.url.description), status code \(request.code)."
    default:
      return stringify(error)
    }
  }
}

struct ResponseDetails {
  let resource: String
  let code: Int
  let message: String?
}

struct RequestFailure {
  let url: URL
  let code: Int
  let data: Data?
}

struct ErrorMessage: Codable {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

struct Errors: Codable {
  static let empty = Errors(errors: [])
  let errors: [SingleError]
}

struct SingleError: Codable {
  let key: String
  let message: String
}

class HttpResponse {
  let http: HTTPURLResponse
  let data: Data

  var statusCode: Int { http.statusCode }
  var isStatusOK: Bool { statusCode >= 200 && statusCode < 300 }

  var errors: [SingleError] {
    let decoder = JSONDecoder()
    return ((try? decoder.decode(Errors.self, from: data)) ?? Errors.empty).errors
  }

  var isTokenExpired: Bool {
    errors.contains { $0.key == "token_expired" }
  }

  init(http: HTTPURLResponse, data: Data) {
    self.http = http
    self.data = data
  }
}
