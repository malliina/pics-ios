//
//  PicsService.swift
//  pics-ios
//
//  Created by Michael Skogberg on 22/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class PicsLibrary {
    let log = LoggerFactory.shared.network(PicsLibrary.self)
    let http: PicsHttpClient
    
    init(http: PicsHttpClient) {
        self.http = http
    }
    
    func load(from: Int, limit: Int, onError: @escaping (AppError) -> Void, onResult: @escaping ([PicMeta]) -> Void) {
        return http.picsGetParsed("/pics?offset=\(from)&limit=\(limit)", parse: PicsLibrary.parsePics, f: onResult, onError: onError)
    }
    
    func save(picture: Data, clientKey: String, onError: @escaping (AppError) -> Void, onResult: @escaping (PicMeta) -> Void) {
        return http.picsPostParsed("/pics", data: picture, clientKey: clientKey, parse: PicsLibrary.parsePic, f: onResult, onError: onError)
    }
    
    static func isPing(obj: AnyObject) throws -> Bool {
        let dict = try readObject(obj)
        let eventValue = dict["event"] as? String
        return eventValue == "ping"
    }
    
    static func parsePics(obj: AnyObject) throws -> [PicMeta] {
        let dict = try readObject(obj)
        let pics: [NSDictionary] = try Json.readOrFail(dict, PicMeta.Pics)
        return try pics.map(PicMeta.parse)
    }
    
    static func parseKeys(obj: AnyObject) throws -> [String] {
        let dict = try readObject(obj)
        let keys: [String] = try Json.readOrFail(dict, "keys")
        return keys
    }
    
    static func parsePic(obj: AnyObject) throws -> PicMeta {
        let dict = try readObject(obj)
        let pics: NSDictionary = try Json.readOrFail(dict, PicMeta.Pic)
        return try PicMeta.parse(pics)
    }
    
    static func readObject(_ obj: AnyObject) throws -> NSDictionary {
        if let obj = obj as? NSDictionary {
            return obj
        }
        throw JsonError.invalid("object", obj)
    }
}
