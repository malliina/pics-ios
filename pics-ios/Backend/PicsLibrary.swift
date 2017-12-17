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
        return http.picsGetParsed("/pics?offset=\(from)&limit=\(limit)", parse: parsePics, f: onResult, onError: onError)
    }
    
    func save(picture: Data, onError: @escaping (AppError) -> Void, onResult: @escaping (PicMeta) -> Void) {
        return http.picsPostParsed("/pics", data: picture, parse: parsePic, f: onResult, onError: onError)
    }
    
    private func parsePics(obj: AnyObject) throws -> [PicMeta] {
        let dict = try readObject(obj)
        let pics: [NSDictionary] = try Json.readOrFail(dict, PicMeta.Pics)
        return try pics.map(PicMeta.parse)
    }
    
    private func parsePic(obj: AnyObject) throws -> PicMeta {
        let dict = try readObject(obj)
        let pics: NSDictionary = try Json.readOrFail(dict, PicMeta.Pic)
        return try PicMeta.parse(pics)
    }
    
    private func readObject(_ obj: AnyObject) throws -> NSDictionary {
        if let obj = obj as? NSDictionary {
            return obj
        }
        throw JsonError.invalid("object", obj)
    }
}
