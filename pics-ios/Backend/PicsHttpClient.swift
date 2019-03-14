//
//  PicsHttpClient.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider
import RxSwift

class PicsHttpClient: HttpClient {
    private let log = LoggerFactory.shared.network(PicsHttpClient.self)
    let baseURL: URL
    private var defaultHeaders: [String: String]
    private let postSpecificHeaders: [String: String]
    
    var postHeaders: [String: String] { return defaultHeaders.merging(postSpecificHeaders)  { (current, _) in current } }
    
    static let PicsVersion10 = "application/vnd.pics.v10+json"
//    static let PicsVersion10 = "application/json"
    static let ClientPicHeader = "X-Client-Pic"
    
    convenience init(accessToken: AWSCognitoIdentityUserSessionToken?) {
        if let accessToken = accessToken {
            self.init(baseURL: EnvConf.BaseUrl, authValue: PicsHttpClient.authValueFor(forToken: accessToken))
        } else {
            self.init(baseURL: EnvConf.BaseUrl, authValue: nil)
        }
    }
    
    init(baseURL: URL, authValue: String?) {
        self.baseURL = baseURL
        if let authValue = authValue {
            self.defaultHeaders = [
                HttpClient.authorization: authValue,
                HttpClient.accept: PicsHttpClient.PicsVersion10
            ]
        } else {
            self.defaultHeaders = [
                HttpClient.accept: PicsHttpClient.PicsVersion10
            ]
        }
        self.postSpecificHeaders = [
            HttpClient.contentType: HttpClient.json
        ]
    }
    
    static func authValueFor(forToken: AWSCognitoIdentityUserSessionToken) -> String {
        return "Bearer \(forToken.tokenString)"
    }
    
    func pingAuth() -> Single<Version> {
        return picsGetParsed("/ping", Version.self)
    }
    
    func picsGetParsed<T: Decodable>(_ resource: String, _ to: T.Type) -> Single<T> {
        return picsGet(resource).flatMap { (response) -> Single<T> in
            return self.parseAs(response: response, to)
        }
    }
    
    func picsPostParsed<T: Decodable>(_ resource: String, data: Data, clientKey: ClientKey, _ to: T.Type) -> Single<T> {
        return picsPost(resource, payload: data, clientKey: clientKey).flatMap { (response) -> Single<T> in
            return self.parseAs(response: response, to)
        }
    }
    
    private func parseAs<T: Decodable>(response: HttpResponse, _ to: T.Type) -> Single<T> {
        let decoder = JSONDecoder()
        do {
            return Single.just(try decoder.decode(to, from: response.data))
        } catch let err {
            return Single.error(err)
        }
    }
    
    func picsGet(_ resource: String) -> Single<HttpResponse> {
        let url = urlFor(resource: resource)
        return statusChecked(resource, response: self.get(url, headers: defaultHeaders))
    }
    
    func picsPost(_ resource: String, payload: Data, clientKey: ClientKey) -> Single<HttpResponse> {
        let url = urlFor(resource: resource)
        return statusChecked(resource, response: self.postData(url, headers: headersFor(clientKey: clientKey), payload: payload))
    }
    
    func picsDelete(_ resource: String) -> Single<HttpResponse> {
        let url = URL(string: resource, relativeTo: baseURL)!
        return statusChecked(resource, response: self.delete(url, headers: defaultHeaders))
    }
    
    func urlFor(resource: String) -> URL {
        return URL(string: resource, relativeTo: baseURL)!
    }
    
    func headersFor(clientKey: ClientKey) -> [String: String] {
        return postHeaders.merging([PicsHttpClient.ClientPicHeader: clientKey.key]) { (current, _) in current }
    }
    
    func statusChecked(_ resource: String, response: Single<HttpResponse>) -> Single<HttpResponse> {
        return response.flatMap { (response) -> Single<HttpResponse> in
            if response.isStatusOK {
                return Single.just(response)
            } else {
                self.log.error("Request to '\(resource)' failed with status '\(response.statusCode)'.")
                let details = ResponseDetails(resource: resource, code: response.statusCode, message: response.errors.first?.message)
                return Single.error(AppError.responseFailure(details))
            }
        }
    }
    
    override func executeHttp(_ req: URLRequest, retryCount: Int = 0) -> Single<HttpResponse> {
        var r = req
        r.addValue("\(retryCount)", forHTTPHeaderField: "X-Retry")
        return super.executeHttp(r).flatMap { (response) -> Single<HttpResponse> in
            if retryCount == 0 && response.statusCode == 401 && response.isTokenExpired {
                return Tokens.shared.retrieve(cancellationToken: nil).flatMap { (token) -> Single<HttpResponse> in
                    self.updateToken(token: token)
                    r.setValue(PicsHttpClient.authValueFor(forToken: token), forHTTPHeaderField: HttpClient.authorization)
                    return self.executeHttp(r, retryCount: retryCount + 1)
                }
            } else {
                return Single.just(response)
            }
        }
    }
    
    func handleError(error: AppError) {
        log.error(error.describe)
    }
    
    func updateToken(token: AWSCognitoIdentityUserSessionToken?) {
        if let token = token {
            self.defaultHeaders.updateValue(PicsHttpClient.authValueFor(forToken: token), forKey: HttpClient.authorization)
        } else {
            self.defaultHeaders.removeValue(forKey: HttpClient.authorization)
        }
    }
    
    func onRequestError(_ data: Data, error: NSError) -> Void {
        log.error("Error: \(data)")
    }
}
