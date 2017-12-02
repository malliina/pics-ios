//
//  PicsService.swift
//  pics-ios
//
//  Created by Michael Skogberg on 22/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class PicsLibrary {
    let log = LoggerFactory.shared.network("PicsLibrary")
    let http: PicsHttpClient
    
    init(http: PicsHttpClient) {
        self.http = http
    }
    
    func load(from: Int, limit: Int, onResult: @escaping ([PicMeta]) -> Void) {
        return http.picsGetParsed("/pics?offset=\(from)&limit=\(limit)", parse: parsePics, f: onResult, onError: onError)
    }
    
    func parsePics(obj: AnyObject) throws -> [PicMeta] {
        let dict = try readObject(obj)
        let pics: [NSDictionary] = try Json.readOrFail(dict, PicMeta.Pics)
        return try pics.map(PicMeta.parse)
    }
    
    func onError(_ error: AppError) {
        log.error(AppError.stringify(error))
    }
    
    func readObject(_ obj: AnyObject) throws -> NSDictionary {
        if let obj = obj as? NSDictionary {
            return obj
        }
        throw JsonError.invalid("object", obj)
        
    }
}
