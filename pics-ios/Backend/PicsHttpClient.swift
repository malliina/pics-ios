//
//  PicsHttpClient.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

class PicsHttpClient: HttpClient {
    private let log = LoggerFactory.shared.network(PicsHttpClient.self)
    let baseURL: URL
    private var defaultHeaders: [String: String]
    private let postSpecificHeaders: [String: String]
    
    var postHeaders: [String: String] { return defaultHeaders.merging(postSpecificHeaders)  { (current, _) in current } }
    
    static let PicsVersion10 = "application/vnd.pics.v10+json"
//    static let PicsVersion10 = "application/json"
    static let ClientPicHeader = "X-Client-Pic"
    
    static let DevUrl = "http://10.0.0.21:9000"
    static let ProdUrl = "https://pics.malliina.com"
    
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
    
    func pingAuth(_ onError: @escaping (AppError) -> Void, f: @escaping (Version) -> Void) {
        picsGetParsed("/ping", parse: Version.parse, f: f, onError: onError)
    }
    
    func picsGetParsed<T>(_ resource: String, parse: @escaping (AnyObject) throws -> T, f: @escaping (T) -> Void, onError: @escaping (AppError) -> Void) {
        picsGet(resource, f: {
            (data: Data) -> Void in
            if let obj: AnyObject = Json.asJson(data) {
                do {
                    let parsed = try parse(obj)
                    f(parsed)
                } catch let error as JsonError {
                    self.log.error("Parse error.")
                    onError(.parseError(error))
                } catch _ {
                    onError(.simple("Unknown parse error."))
                }
            } else {
                self.log.error("Not JSON: \(data)")
                onError(AppError.parseError(JsonError.notJson(data)))
            }
        }, onError: onError)
    }
    
    func picsPostParsed<T>(_ resource: String, data: Data, clientKey: String, parse: @escaping (AnyObject) throws -> T, f: @escaping (T) -> Void, onError: @escaping (AppError) -> Void) {
        picsPost(resource, payload: data, clientKey: clientKey, f: {
            (data: Data) -> Void in
            if let obj: AnyObject = Json.asJson(data) {
                do {
                    let parsed = try parse(obj)
                    f(parsed)
                } catch let error as JsonError {
                    self.log.error("Parse error.")
                    onError(.parseError(error))
                } catch _ {
                    onError(.simple("Unknown parse error."))
                }
            } else {
                self.log.error("Not JSON: \(data)")
                onError(AppError.parseError(JsonError.notJson(data)))
            }
        }, onError: onError)
    }
    
    func picsGet(_ resource: String, f: @escaping (Data) -> Void, onError: @escaping (AppError) -> Void) {
        let url = URL(string: resource, relativeTo: baseURL)!
        self.get(
            url,
            headers: defaultHeaders,
            onResponse: { response -> Void in
                self.responseHandler(resource, response: response, f: f, onError: onError)
        },
            onError: { (err) -> Void in
                onError(.networkFailure(err))
        })
    }
    
    func picsPost(_ resource: String, payload: Data, clientKey: String, f: @escaping (Data) -> Void, onError: @escaping (AppError) -> Void) {
        let url = URL(string: resource, relativeTo: baseURL)!
        self.postData(
            url,
            headers: postHeaders.merging([PicsHttpClient.ClientPicHeader: clientKey]) { (current, _) in current },
            payload: payload,
            onResponse: { response -> Void in
                self.responseHandler(resource, response: response, f: f, onError: onError)
        },
            onError: { (err) -> Void in
                onError(.networkFailure(err))
        })
    }
    
    func responseHandler(_ resource: String, response: HttpResponse, f: (Data) -> Void, onError: (AppError) -> Void) {
        if response.isStatusOK {
//            log.info("Response to '\(resource)' received with status '\(statusCode)'.")
            f(response.data)
        } else {
            log.error("Request to '\(resource)' failed with status '\(response.statusCode)'.")
            var errorMessage: String? = nil
            if let json = Json.asJson(response.data) as? NSDictionary {
                errorMessage = json[JsonError.Key] as? String
            }
            onError(.responseFailure(ResponseDetails(resource: resource, code: response.statusCode, message: errorMessage)))
        }
    }
    
    override func executeHttp(_ req: URLRequest, onResponse: @escaping (HttpResponse) -> Void, onError: @escaping (RequestFailure) -> Void, retryCount: Int = 0) {
        let url = req.url!
        var r = req
        r.addValue("\(retryCount)", forHTTPHeaderField: "X-Retry")
        super.executeHttp(r, onResponse: { (response) in
            if retryCount == 0 && response.statusCode == 401 && response.isTokenExpired {
                self.log.info("Token expired, retrieving new token and retrying...")
                Tokens.shared.retrieveToken(onToken: { (token) in
                    self.defaultHeaders.updateValue(PicsHttpClient.authValueFor(forToken: token), forKey: HttpClient.AUTHORIZATION)
                    r.setValue(PicsHttpClient.authValueFor(forToken: token), forHTTPHeaderField: HttpClient.AUTHORIZATION)
                    self.executeHttp(r, onResponse: onResponse, onError: onError, retryCount: retryCount + 1)
                })
            } else {
                self.log.info("Got a response for request to \(url).")
                onResponse(response)
            }
        }, onError: onError, retryCount: retryCount)
    }
    
    func onRequestError(_ data: Data, error: NSError) -> Void {
        log.error("Error: \(data)")
    }
}
