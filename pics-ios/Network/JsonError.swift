import Foundation

enum JsonError: Error {
  static let Key = "error"
  case notJson(Data)
  case missing(String)
  case invalid(String, Any)
  
  var describe: String {
    switch self {
    case .missing(let key):
      return "Key not found: '\(key)'."
    case .invalid(let key, let actual):
      return "Invalid '\(key)' value: '\(actual)'."
    case .notJson(_):
      return "Invalid response format. Expected JSON."
    }
  }
}
