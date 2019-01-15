//
//  PicsService.swift
//  pics-ios
//
//  Created by Michael Skogberg on 22/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import RxSwift

typealias ClientKey = String

class PicsLibrary {
    let log = LoggerFactory.shared.network(PicsLibrary.self)
    let http: PicsHttpClient
    
    init(http: PicsHttpClient) {
        self.http = http
    }
    
    func load(from: Int, limit: Int) -> Observable<[PicMeta]> {
        return http.picsGetParsed("/pics?offset=\(from)&limit=\(limit)", parse: PicsLibrary.parsePics)
    }
    
    func save(picture: Data, clientKey: ClientKey) -> Observable<PicMeta> {
        return http.picsPostParsed("/pics", data: picture, clientKey: clientKey, parse: PicsLibrary.parsePic)
    }
    
    func delete(key: String) -> Observable<HttpResponse> {
        return http.picsDelete("/pics/\(key)")
    }
    
    func syncOffline(for user: String) {
        let dir = LocalPics.shared.directory(for: user)
        let files = LocalPics.listFiles(at: dir).sorted { (file1, file2) -> Bool in
            file1.created < file2.created
        }
        log.info("Syncing \(files.count) files for '\(user)'...")
        files.forEach { (url) in
            uploadPic(picture: url, clientKey: Picture.randomKey(), deleteOnComplete: true)
        }
    }
    
    func uploadPic(picture: URL, clientKey: ClientKey, deleteOnComplete: Bool = false) {
        let url = http.urlFor(resource: "/pics")
        let headers = http.headersFor(clientKey: clientKey)
        BackgroundTransfers.uploader.upload(url, headers: headers, file: picture, deleteOnComplete: deleteOnComplete)
    }
    
    func handle<T>(result: TransferResult, parse: (Data) throws -> T) -> Observable<T> {
        if let error = result.error {
            return Observable.error(AppError.networkFailure(RequestFailure(url: result.url, code: error._code, data: result.data)))
        } else if let httpResponse = result.httpResponse {
            if httpResponse.isStatusOK {
                do {
                    let parsed = try parse(httpResponse.data)
                    return Observable.just(parsed)
//                    onResult(parsed)
                } catch let error as JsonError {
                    self.log.error("Parse error.")
                    return Observable.error(AppError.parseError(error))
                    
                } catch _ {
                    return Observable.error(AppError.simple("Unknown parse error."))
                }
            } else {
                log.error("Request to '\(result.url.absoluteString)' failed with status '\(httpResponse.statusCode)'.")
                var errorMessage: String? = nil
                if let json = Json.asJson(httpResponse.data) as? NSDictionary {
                    errorMessage = json[JsonError.Key] as? String
                }
                return Observable.error(AppError.responseFailure(ResponseDetails(resource: result.url.absoluteString, code: httpResponse.statusCode, message: errorMessage)))
            }
        } else {
            return Observable.error(AppError.simpleError(ErrorMessage(message: "Unknown HTTP response.")))
        }
    }
    
    static func parsePics(obj: AnyObject) throws -> [PicMeta] {
        let dict = try Json.readObject(obj)
        let pics: [NSDictionary] = try Json.readOrFail(dict, PicMeta.Pics)
        return try pics.map(PicMeta.parse)
    }
    
    static func parseKeys(obj: AnyObject) throws -> [String] {
        let dict = try Json.readObject(obj)
        let keys: [String] = try Json.readOrFail(dict, "keys")
        return keys
    }
    
//    static func parsePicData(data: Data) throws -> PicMeta {
//        guard let obj = Json.asJson(data) else { throw JsonError.notJson(data) }
//        return try parsePic(obj: obj)
//    }
    
    static func parsePic(obj: AnyObject) throws -> PicMeta {
        let dict = try Json.readObject(obj)
        let pics: NSDictionary = try Json.readOrFail(dict, PicMeta.Pic)
        return try PicMeta.parse(pics)
    }
}
