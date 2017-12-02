//
//  models.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

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

class PicMeta {
    static let Pics = "pics"
    static let Key = "key"
    static let Url = "url"
    static let Thumb = "thumb"
    
    let key: String
    let url: URL
    let thumb: URL
    
    init(key: String, url: URL, thumb: URL) {
        self.key = key
        self.url = url
        self.thumb = thumb
    }
    
    static func parse(_ obj: AnyObject) throws -> PicMeta {
        if let dict = obj as? NSDictionary {
            let key = try Json.readString(dict, PicMeta.Key)
            let urlStr = try Json.readString(dict, PicMeta.Url)
            let thumbStr = try Json.readString(dict, PicMeta.Thumb)
            guard let url = URL(string: urlStr) else { throw JsonError.invalid(PicMeta.Url, obj) }
            guard let thumb = URL(string: thumbStr) else { throw JsonError.invalid(PicMeta.Thumb, obj) }
            return PicMeta(key: key, url: url, thumb: thumb)
        }
        throw JsonError.invalid("meta", obj)
    }
}

class Picture {
    let meta: PicMeta
    var url: UIImage? = nil
    var thumb: UIImage? = nil
    
    init(meta: PicMeta) {
        self.meta = meta
    }
}
