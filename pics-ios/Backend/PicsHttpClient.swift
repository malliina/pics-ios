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
                HttpClient.AUTHORIZATION: authValue,
                HttpClient.ACCEPT: PicsHttpClient.PicsVersion10
            ]
        } else {
            self.defaultHeaders = [
                HttpClient.ACCEPT: PicsHttpClient.PicsVersion10
            ]
        }
        self.postSpecificHeaders = [
            HttpClient.CONTENT_TYPE: HttpClient.JSON
        ]
    }
    
    static func authValueFor(forToken: AWSCognitoIdentityUserSessionToken) -> String {
        return "Bearer \(forToken.tokenString)"
    }
    
    func pingAuth() -> Observable<Version> {
        return picsGetParsed("/ping", parse: Version.parse)
    }
    
    func picsGetParsed<T>(_ resource: String, parse: @escaping (AnyObject) throws -> T) -> Observable<T> {
        return picsGet(resource).flatMap { (response) -> Observable<T> in
            return self.parseAs(response: response, parse: parse)
        }
    }
    
    func picsPostParsed<T>(_ resource: String, data: Data, clientKey: ClientKey, parse: @escaping (AnyObject) throws -> T) -> Observable<T> {
        return picsPost(resource, payload: data, clientKey: clientKey).flatMap { (response) -> Observable<T> in
            return self.parseAs(response: response, parse: parse)
        }
    }
    
    private func parseAs<T>(response: HttpResponse, parse: @escaping (AnyObject) throws -> T) -> Observable<T> {
        if let obj: AnyObject = Json.asJson(response.data) {
            do {
                let parsed = try parse(obj)
                return Observable.just(parsed)
            } catch let error as JsonError {
                self.log.error("Parse error.")
                return Observable.error(AppError.parseError(error))
            } catch _ {
                return Observable.error(AppError.simple("Unknown parse error."))
            }
        } else {
            self.log.error("Not JSON: \(response.data)")
            return Observable.error(AppError.parseError(JsonError.notJson(response.data)))
        }
    }
    
    func picsGet(_ resource: String) -> Observable<HttpResponse> {
        let url = urlFor(resource: resource)
        return statusChecked(resource, response: self.get(url, headers: defaultHeaders))
    }
    
    func picsPost(_ resource: String, payload: Data, clientKey: ClientKey) -> Observable<HttpResponse> {
        let url = urlFor(resource: resource)
        return statusChecked(resource, response: self.postData(url, headers: headersFor(clientKey: clientKey), payload: payload))
    }
    
    func picsDelete(_ resource: String) -> Observable<HttpResponse> {
        let url = URL(string: resource, relativeTo: baseURL)!
        return statusChecked(resource, response: self.delete(url, headers: defaultHeaders))
    }
    
    func urlFor(resource: String) -> URL {
        return URL(string: resource, relativeTo: baseURL)!
    }
    
    func headersFor(clientKey: ClientKey) -> [String: String] {
        return postHeaders.merging([PicsHttpClient.ClientPicHeader: clientKey]) { (current, _) in current }
    }
    
    func statusChecked(_ resource: String, response: Observable<HttpResponse>) -> Observable<HttpResponse> {
        return response.flatMap { (response) -> Observable<HttpResponse> in
            if response.isStatusOK {
                return Observable.just(response)
            } else {
                self.log.error("Request to '\(resource)' failed with status '\(response.statusCode)'.")
                var errorMessage: String? = nil
                if let json = Json.asJson(response.data) as? NSDictionary {
                    errorMessage = json[JsonError.Key] as? String
                }
                return Observable.error(AppError.responseFailure(ResponseDetails(resource: resource, code: response.statusCode, message: errorMessage)))
            }
        }
    }
    
    override func executeHttp(_ req: URLRequest, retryCount: Int = 0) -> Observable<HttpResponse> {
        var r = req
        r.addValue("\(retryCount)", forHTTPHeaderField: "X-Retry")
        return super.executeHttp(r).flatMap { (response) -> Observable<HttpResponse> in
            if retryCount == 0 && response.statusCode == 401 && response.isTokenExpired {
                return Tokens.shared.retrieve(cancellationToken: nil).flatMap { (token) -> Observable<HttpResponse> in
                    self.updateToken(token: token)
                    r.setValue(PicsHttpClient.authValueFor(forToken: token), forHTTPHeaderField: HttpClient.AUTHORIZATION)
                    return self.executeHttp(r, retryCount: retryCount + 1)
                }
            } else {
                return Observable.just(response)
            }
        }
    }
    
    func handleError(error: AppError) {
        log.error(error.describe)
    }
    
    func updateToken(token: AWSCognitoIdentityUserSessionToken?) {
        if let token = token {
            self.defaultHeaders.updateValue(PicsHttpClient.authValueFor(forToken: token), forKey: HttpClient.AUTHORIZATION)
        } else {
            self.defaultHeaders.removeValue(forKey: HttpClient.AUTHORIZATION)
        }
    }
    
    func onRequestError(_ data: Data, error: NSError) -> Void {
        log.error("Error: \(data)")
    }
}
