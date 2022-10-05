//
//  models.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class PasswordCredentials {
    let username: String
    let password: String
    
    init(user: String, pass: String) {
        self.username = user
        self.password = pass
    }
    
    func toCognito() -> AWSCognitoIdentityPasswordAuthenticationDetails? {
        AWSCognitoIdentityPasswordAuthenticationDetails(username: self.username, password: self.password)
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
        if let message = err.userInfo["message"] as? String, let type = err.userInfo["__type"] as? String {
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
        ClientKey(Picture.randomKey())
    }
}

struct AccessToken: Equatable, Hashable, CustomStringConvertible {
    let token: String
    var description: String { token }
    
    static func == (lhs: AccessToken, rhs: AccessToken) -> Bool { lhs.token == rhs.token }
}

struct PicRef: Codable {
    let filename: String
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

struct PicMeta: Codable, Hashable {
    static let Pic = "pic"
    static let Pics = "pics"
    
    let key: ClientKey
    let url: URL
    let small: URL
    let medium: URL
    let large: URL
    let added: Timestamp
    let clientKey: ClientKey?
    
    static func ref(_ ref: PicRef) -> PicMeta? {
        let local = LocalPics.shared
        let key = ClientKey(ref.filename)
        let url = local.findLocal(key: key)
        let smallUrl = local.findSmallUrl(key: key)
        guard let large = url ?? smallUrl else { return nil }
        return PicMeta(key: key, url: large, small: smallUrl ?? large, medium: large, large: large, added: ref.added, clientKey: key)
    }
    
    static func oneUrl(key: ClientKey, url: URL, added: Timestamp, clientKey: ClientKey?) -> PicMeta {
        PicMeta(key: key, url: url, small: url, medium: url, large: url, added: added, clientKey: clientKey)
    }
    
    func withUrl(url: URL) -> PicMeta {
        PicMeta.oneUrl(key: key, url: url, added: added, clientKey: clientKey)
    }
}

typealias Timestamp = UInt64

struct Picture {
    let meta: PicMeta
    
    var url: UIImage? = nil
    var small: UIImage? = nil
    var medium: UIImage? = nil
    var large: UIImage? = nil
    
    init(url: URL, image: UIImage, clientKey: ClientKey) {
        let millis = Picture.nowMillis()
        self.init(url: url, image: image, clientKey: clientKey, added: millis)
    }
    
    init(url: URL, image: UIImage, added: Timestamp) {
        self.init(url: url, image: image, clientKey: ClientKey.random(), added: added)
    }
    
    init(url: URL, image: UIImage, clientKey: ClientKey, added: Timestamp) {
        self.init(meta: PicMeta.oneUrl(key: clientKey, url: url, added: added, clientKey: clientKey))
        self.url = image
        small = image
        medium = image
        large = image
    }
    
    init(meta: PicMeta) {
        self.meta = meta
    }
    
    var preferred: UIImage? { url ?? large ?? medium ?? small }
    
    static func nowMillis() -> Timestamp {
        Timestamp(Date().timeIntervalSince1970 * 1000)
    }
    
    static func randomKey() -> String {
        String(UUID().uuidString.prefix(7)).lowercased()
    }
}

struct KeyedEvent: Codable {
    let event: String
}
