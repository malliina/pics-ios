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
        return AWSCognitoIdentityPasswordAuthenticationDetails(username: self.username, password: self.password)
    }
}

enum SignupError {
    case userNotFound(String)
    case invalidCredentials(String)
    case userAlreadyExists(String)
    case weakPassword(String)
    case userNotConfirmed(String)
    case codeExpired(String)
    case invalidCode(String)
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
            return .unknown
        }
    }
}

class Version {
    static let Key = "version"
    
    let version: String
    
    init(version: String) {
        self.version = version
    }
    
    static func parse(_ obj: AnyObject) throws -> Version {
        if let dict = obj as? NSDictionary {
            let version = try Json.readString(dict, Version.Key)
            return Version(version: version)
        }
        throw JsonError.missing(Version.Key)
    }
}

class FullUrl {
    static let Key = "url"
    
    let proto: String
    let host: String
    let uri: String
    
    var url: String { return "\(proto)://\(host)\(uri)" }
    
    init(proto: String, host: String, uri: String) {
        self.proto = proto
        self.host = host
        self.uri = uri
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

class ProfileInfo {
    static let User = "user"
    static let ReadOnly = "readOnly"
    
    let user: String
    let readOnly: Bool
    
    init(user: String, readOnly: Bool) {
        self.user = user
        self.readOnly = readOnly
    }
    
    static func parse(_ obj: AnyObject) throws -> ProfileInfo {
        guard let dict = obj as? NSDictionary else { throw JsonError.invalid("object", obj) }
        let user = try Json.readString(dict, User)
        let readOnly: Bool = try Json.readOrFail(dict, ReadOnly)
        return ProfileInfo(user: user, readOnly: readOnly)
    }
}

class PicMeta {
    static let Pic = "pic"
    static let Pics = "pics"
    static let Key = "key"
    static let Url = "url"
    static let Small = "small"
    static let Medium = "medium"
    static let Large = "large"
    static let Added = "added"
    static let ClientKey = "clientKey"
    
    let key: String
    let url: URL
    let small: URL
    let medium: URL
    let large: URL
    let added: Timestamp
    let clientKey: String?
    
    convenience init(key: String, url: URL, added: Timestamp, clientKey: String?) {
        self.init(key: key, url: url, small: url, medium: url, large: url, added: added, clientKey: clientKey)
    }
    
    init(key: String, url: URL, small: URL, medium: URL, large: URL, added: Timestamp, clientKey: String?) {
        self.key = key
        self.url = url
        self.small = small
        self.medium = medium
        self.large = large
        self.added = added
        self.clientKey = clientKey
    }
    
    func withUrl(url: URL) -> PicMeta {
        return PicMeta(key: key, url: url, added: added, clientKey: clientKey)
    }
    
    static func write(pic: PicMeta) -> [String: AnyObject] {
        return [
            Key: pic.key as AnyObject,
            Url: pic.url.absoluteString as AnyObject,
            Small: pic.small.absoluteString as AnyObject,
            Medium: pic.medium.absoluteString as AnyObject,
            Large: pic.large.absoluteString as AnyObject,
            Added: pic.added as AnyObject,
            ClientKey: pic.clientKey as AnyObject
        ]
    }
    
    static func readUrl(key: String, dict: NSDictionary) throws -> URL {
        let asString = try Json.readString(dict, key)
        if let url = URL(string: asString) {
            return url
        } else {
            throw JsonError.invalid(key, dict)
        }
    }
    
    static func parse(_ obj: AnyObject) throws -> PicMeta {
        if let dict = obj as? NSDictionary {
            let key = try Json.readString(dict, PicMeta.Key)
            let url = try readUrl(key: PicMeta.Url, dict: dict)
            let small = try readUrl(key: Small, dict: dict)
            let medium = try readUrl(key: Medium, dict: dict)
            let large = try readUrl(key: Large, dict: dict)
            let added: Timestamp = try Json.readOrFail(dict, Added)
            let clientKey = try? Json.readString(dict, ClientKey)
            return PicMeta(key: key, url: url, small: small, medium: medium, large: large, added: added, clientKey: clientKey)
        }
        throw JsonError.invalid("meta", obj)
    }
}

typealias Timestamp = UInt64

class Picture {
    static let TempFakeUrl = URL(string: "https://pics.malliina.com")!
    let meta: PicMeta
    var url: UIImage? = nil
    var small: UIImage? = nil
    var medium: UIImage? = nil
    var large: UIImage? = nil
    
    convenience init(image: UIImage) {
        let millis = Timestamp(Date().timeIntervalSince1970 * 1000)
        self.init(url: Picture.TempFakeUrl, image: image, added: millis)
    }
    
    convenience init(image: UIImage, added: Timestamp) {
        self.init(url: Picture.TempFakeUrl, image: image, added: added)
    }
    
    convenience init(url: URL, image: UIImage, added: Timestamp) {
        let clientKey: String = String(UUID().uuidString.prefix(7)).lowercased()
        self.init(meta: PicMeta(key: clientKey, url: url, added: added, clientKey: clientKey))
        self.url = image
        small = image
        medium = image
        large = image
    }
    
    init(meta: PicMeta) {
        self.meta = meta
    }
    
    func withMeta(meta: PicMeta) -> Picture {
        let other = Picture(meta: meta)
        other.url = url
        other.small = small
        other.medium = medium
        other.large = large
        return other
    }
    
    func withUrl(url: URL) -> Picture {
        return withMeta(meta: meta.withUrl(url: url))
    }
}
