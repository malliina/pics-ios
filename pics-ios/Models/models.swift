import AWSCognitoIdentityProvider
import Foundation
import UIKit

class PasswordCredentials {
  let username: String
  let password: String

  init(user: String, pass: String) {
    self.username = user
    self.password = pass
  }

  func toCognito() -> AWSCognitoIdentityPasswordAuthenticationDetails? {
    AWSCognitoIdentityPasswordAuthenticationDetails(
      username: self.username, password: self.password)
  }
}

enum SignupError: Error {
  case userNotFound(String)
  case invalidCredentials(String)
  case userAlreadyExists(String)
  case weakPassword(String)
  case passwordMismatch(String)
  case userNotConfirmed(String)
  case codeExpired(String)
  case invalidCode(String)
  case noInternet(String)
  case unknown

  var message: String {
    switch self {
    case .userNotFound(_): return "User not found."
    case .invalidCredentials(_): return "Invalid credentials."
    case .userAlreadyExists(_): return "User already exists."
    case .weakPassword(_): return "Weak password. Minimum 7 characters."
    case .userNotConfirmed(_): return "User not confirmed."
    case .codeExpired(_): return "Code expired."
    case .invalidCode(_): return "Invalid code."
    case .noInternet(_): return "Check your network connectivity."
    case .passwordMismatch(_): return "Passwords do not match."
    default: return "Unknown error."
    }
  }

  static func check(user: String, error: Error?) -> SignupError? {
    guard let error = error as NSError? else { return nil }
    return parse(user: user, error: error)
  }

  static func parse(user: String, error: Error) -> SignupError {
    let err: NSError = error as NSError
    if let message = err.userInfo["message"] as? String,
      let type = err.userInfo["__type"] as? String
    {
      switch type {
      case "UserNotFoundException": return .userNotFound(user)
      case "NotAuthorizedException": return .invalidCredentials(user)
      case "UsernameExistsException": return .userAlreadyExists(user)
      case "InvalidParameterException": return .weakPassword(message)
      case "UserNotConfirmedException": return .userNotConfirmed(user)
      case "ExpiredCodeException": return .codeExpired(user)
      case "CodeMismatchException": return .invalidCode(user)
      default: return .unknown
      }
    } else {
      guard let urlError = error as? URLError else { return .unknown }
      switch urlError.code {
      case .notConnectedToInternet:
        return .noInternet(user)
      default:
        return .unknown
      }
    }
  }
}

struct Version: Codable {
  let version: String
}

struct FullUrl: ValidatedValueCodable {
  static let Key = "url"

  let proto: String
  let host: String
  let uri: String

  var url: String { "\(proto)://\(host)\(uri)" }
  var value: String { url }

  init(proto: String, host: String, uri: String) {
    self.proto = proto
    self.host = host
    self.uri = uri
  }

  init(_ value: String) throws {
    self = try FullUrl.parse(input: value)
  }

  static func parse(input: String) throws -> FullUrl {
    let results = try matches(for: "(.+)://([^/]+)(/?.*)", in: input)
    if results.count == 3 {
      return FullUrl(proto: results[0], host: results[1], uri: results[2])
    } else {
      throw JsonError.invalid(FullUrl.Key, input)
    }
  }

  static func matches(for regex: String, in text: String) throws -> [String] {
    let regex = try NSRegularExpression(pattern: regex)
    let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    var ret: [String] = []
    if let result = results.first {
      for index in 1..<result.numberOfRanges {
        ret.append(String(text[Range(result.range(at: index), in: text)!]))
      }
    }
    return ret
  }
}

struct Username: Equatable, Hashable, ValueCodable {
  static let anon = Username("anon")
  let user: String
  var value: String { user }

  init(_ value: String) {
    self.user = value
  }

  func encoded() -> String { Data(user.utf8).hexEncodedString() }
}

struct ProfileInfo: Codable {
  let user: Username
  let readOnly: Bool
}

struct ClientKeys: Codable {
  let keys: [ClientKey]
}

struct ClientKey: Equatable, Hashable, CustomStringConvertible, ValueCodable {
  let key: String
  var value: String { key }

  init(_ value: String) {
    self.key = value
  }

  static func == (lhs: ClientKey, rhs: ClientKey) -> Bool { lhs.key == rhs.key }

  static func random() -> ClientKey {
    ClientKey(PicMeta.randomKey())
  }
}

struct AccessToken: Hashable, CustomStringConvertible {
  let token: String
  var description: String { token }

  static func == (lhs: AccessToken, rhs: AccessToken) -> Bool { lhs.token == rhs.token }
}

struct AccessValue: Hashable, CustomStringConvertible, ValueCodable {
  static let priv = AccessValue("private")
  static let pub = AccessValue("public")
  let access: String
  var value: String { access }
  var picAccess: PicAccess {
    switch value {
    case AccessValue.priv.value: return .privateAccess
    case AccessValue.pub.value: return .publicAccess
    default: return .other
    }
  }
  init(_ value: String) {
    self.access = value
  }
  static func == (lhs: AccessValue, rhs: AccessValue) -> Bool { lhs.value == rhs.value }
}

enum PicAccess: String {
  case privateAccess, publicAccess, other
}

struct PicRef: Codable {
  let filename: String
  let access: AccessValue
  let added: Timestamp
}

struct PicRefs: Codable {
  let pics: [PicRef]
}

struct PicResponse: Codable {
  let pic: PicMeta
}

struct PicsResponse: Codable {
  let pics: [PicMeta]
}

struct PicMeta: Codable, Hashable, Identifiable {
  static let Pic = "pic"
  static let Pics = "pics"
  //    private static let log = LoggerFactory.shared.system(PicsVM.self)

  let key: ClientKey
  let url: URL
  let small: URL
  let medium: URL
  let large: URL
  let added: Timestamp
  let clientKey: ClientKey?
  let access: AccessValue
  var visibility: PicAccess { access.picAccess }
  var id: String { key.value }

  static func ref(_ ref: PicRef) -> PicMeta? {
    let local = LocalPics.shared
    let key = ClientKey(ref.filename)
    let url = local.findLocal(key: key)
    let smallUrl = local.findSmallUrl(key: key)
    //        log.info("Ref \(ref.filename) key \(key) url \(url) small \(smallUrl)")
    guard let large = url ?? smallUrl else { return nil }
    return PicMeta(
      key: key, url: large, small: smallUrl ?? large, medium: large, large: large, added: ref.added,
      clientKey: key, access: ref.access)
  }

  static func oneUrl(
    key: ClientKey, url: URL, added: Timestamp, clientKey: ClientKey?, access: AccessValue
  ) -> PicMeta {
    PicMeta(
      key: key, url: url, small: url, medium: url, large: url, added: added, clientKey: clientKey,
      access: access)
  }

  static func local(url: URL, key: ClientKey, access: AccessValue) -> PicMeta {
    PicMeta.oneUrl(key: key, url: url, added: nowMillis(), clientKey: key, access: access)
  }

  func withUrl(url: URL) -> PicMeta {
    PicMeta.oneUrl(key: key, url: url, added: added, clientKey: clientKey, access: access)
  }

  func with(newAccess: AccessValue) -> PicMeta {
    PicMeta(
      key: key, url: url, small: small, medium: medium, large: large, added: added,
      clientKey: clientKey, access: newAccess)
  }

  static func nowMillis() -> Timestamp {
    Timestamp(Date().timeIntervalSince1970 * 1000)
  }

  static func randomKey() -> String {
    String(UUID().uuidString.prefix(7)).lowercased()
  }
}

typealias Timestamp = UInt64

struct KeyedEvent: Codable {
  let event: String
}
