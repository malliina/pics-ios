//
//  PicsService.swift
//  pics-ios
//
//  Created by Michael Skogberg on 22/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import RxSwift

class PicsLibrary {
    let log = LoggerFactory.shared.network(PicsLibrary.self)
    let http: PicsHttpClient
    let lockQueue: DispatchQueue
    
    init(http: PicsHttpClient) {
        self.http = http
        self.lockQueue = DispatchQueue(label: "com.malliina.pics.library", attributes: [])
    }
    
    func synchronized(_ f: @escaping () -> Void) {
        self.lockQueue.async {
            f()
        }
    }
    
    func load(from: Int, limit: Int) -> Single<[PicMeta]> {
        return http.picsGetParsed("/pics?offset=\(from)&limit=\(limit)", PicsResponse.self).map { $0.pics }
    }
    
    func save(picture: Data, clientKey: ClientKey) -> Single<PicMeta> {
        return http.picsPostParsed("/pics", data: picture, clientKey: clientKey, PicResponse.self).map { $0.pic }
    }
    
    func delete(key: ClientKey) -> Single<HttpResponse> {
        return http.picsDelete("/pics/\(key)")
    }
    
    func syncPicsForLatestUser() {
        let _ = Tokens.shared.retrieveUserInfo().subscribe { event in
            switch event {
            case .success(let userInfo):
                Backend.shared.updateToken(new: userInfo.token)
                self.syncOffline(for: userInfo.username)
            case .error(let error):
                self.log.error("Failed to obtain user info. No network? \(error)")
            }
        }
    }
    
    func syncOffline(for user: String) {
        // Runs synchronized so that only one thread moves files from staging to uploading at a time
        synchronized {
            let dir = LocalPics.shared.stagingDirectory(for: user)
            let files = LocalPics.listFiles(at: dir).sorted { (file1, file2) -> Bool in
                file1.created < file2.created
            }
            if files.isEmpty {
                self.log.info("Nothing to sync for user \(user).")
            }
            files.headOption().map { file in
                do {
                    let uploadingUrl = LocalPics.shared.uploadingDirectory(for: user).appendingPathComponent(file.lastPathComponent)
                    try FileManager.default.moveItem(at: file, to: uploadingUrl)
                    self.log.info("Moved \(file) to \(uploadingUrl)")
                    self.log.info("Syncing \(uploadingUrl) for '\(user)' taken at '\(file.created)'. In total \(files.count) files awaiting upload.")
                    self.uploadPic(picture: uploadingUrl, clientKey: LocalPics.shared.extractKey(name: file.lastPathComponent) ?? ClientKey.random(), deleteOnComplete: true)
                } catch let err {
                    self.log.error("Unable to prepare \(file) for upload. \(err)")
                }
            }
        }
    }
    
    func uploadPic(picture: URL, clientKey: ClientKey, deleteOnComplete: Bool = false) {
        let url = http.urlFor(resource: "/pics")
        let headers = http.headersFor(clientKey: clientKey)
        BackgroundTransfers.uploader.upload(url, headers: headers, file: picture, deleteOnComplete: deleteOnComplete)
    }
    
    func handle<T: Decodable>(result: TransferResult, to: T.Type) -> Single<T> {
        if let error = result.error {
            return Single.error(AppError.networkFailure(RequestFailure(url: result.url, code: error._code, data: result.data)))
        } else if let httpResponse = result.httpResponse {
            let decoder = JSONDecoder()
            if httpResponse.isStatusOK {
                do {
                    return Single.just(try decoder.decode(to, from: httpResponse.data))
                } catch let error as JsonError {
                    self.log.error("Parse error.")
                    return Single.error(AppError.parseError(error))
                } catch _ {
                    return Single.error(AppError.simple("Unknown parse error."))
                }
            } else {
                log.error("Request to '\(result.url.absoluteString)' failed with status '\(httpResponse.statusCode)'.")
                let details = ResponseDetails(resource: result.url.absoluteString, code: httpResponse.statusCode, message: httpResponse.errors.first?.message)
                return Single.error(AppError.responseFailure(details))
            }
        } else {
            return Single.error(AppError.simpleError(ErrorMessage("Unknown HTTP response.")))
        }
    }
}
