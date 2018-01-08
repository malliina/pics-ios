//
//  PicsService.swift
//  pics-ios
//
//  Created by Michael Skogberg on 22/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

typealias ClientKey = String

class PicsLibrary {
    let log = LoggerFactory.shared.network(PicsLibrary.self)
    let http: PicsHttpClient
    
    init(http: PicsHttpClient) {
        self.http = http
    }
    
    func load(from: Int, limit: Int, onError: @escaping (AppError) -> Void, onResult: @escaping ([PicMeta]) -> Void) {
        return http.picsGetParsed("/pics?offset=\(from)&limit=\(limit)", parse: PicsLibrary.parsePics, f: onResult, onError: onError)
    }
    
    func save(picture: Data, clientKey: ClientKey, onError: @escaping (AppError) -> Void, onResult: @escaping (PicMeta) -> Void) {
        return http.picsPostParsed("/pics", data: picture, clientKey: clientKey, parse: PicsLibrary.parsePic, f: onResult, onError: onError)
    }
    
    func saveURL(picture: URL, clientKey: ClientKey, onError: @escaping (AppError) -> Void, onResult: @escaping (PicMeta) -> Void) {
        let url = http.urlFor(resource: "/pics")
        let headers = http.headersFor(clientKey: clientKey)
        BackgroundTransfers.picsUploader.upload(url, headers: headers, file: picture) { res in
            self.handle(result: res, parse: PicsLibrary.parsePicData, onResult: onResult, onError: onError)
        }
    }
    
    func handle<T>(result: TransferResult, parse: (Data) throws -> T, onResult: (T) -> Void, onError: (AppError) -> Void) {
        if let error = result.error {
            onError(.networkFailure(RequestFailure(url: result.url, code: error._code, data: result.data)))
        } else if let httpResponse = result.httpResponse {
            if httpResponse.isStatusOK {
                do {
                    let parsed = try parse(httpResponse.data)
                    onResult(parsed)
                } catch let error as JsonError {
                    self.log.error("Parse error.")
                    onError(.parseError(error))
                } catch _ {
                    onError(.simple("Unknown parse error."))
                }
            } else {
                log.error("Request to '\(result.url.absoluteString)' failed with status '\(httpResponse.statusCode)'.")
                var errorMessage: String? = nil
                if let json = Json.asJson(httpResponse.data) as? NSDictionary {
                    errorMessage = json[JsonError.Key] as? String
                }
                onError(.responseFailure(ResponseDetails(resource: result.url.absoluteString, code: httpResponse.statusCode, message: errorMessage)))
            }
        } else {
            onError(.simpleError(ErrorMessage(message: "Unknown HTTP response.")))
        }
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
    
    static func parsePicData(data: Data) throws -> PicMeta {
        guard let obj = Json.asJson(data) else { throw JsonError.notJson(data) }
        return try parsePic(obj: obj)
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
