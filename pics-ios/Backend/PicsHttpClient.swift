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
    let defaultHeaders: [String: String]
    let postHeaders: [String: String]
    
    static let PicsVersion10 = "application/vnd.pics.v10+json"
//    static let PicsVersion10 = "application/json"
    
    static let DevUrl = "http://10.0.0.21:9000"
    static let ProdUrl = "https://pics.malliina.com"
    
    convenience init(accessToken: AWSCognitoIdentityUserSessionToken) {
        self.init(baseURL: URL(string: PicsHttpClient.ProdUrl)!, authValue: "Bearer \(accessToken.tokenString)")
    }
    
    init(baseURL: URL, authValue: String) {
        self.baseURL = baseURL
        let headers = [
            HttpClient.AUTHORIZATION: authValue,
            HttpClient.ACCEPT: PicsHttpClient.PicsVersion10
        ]
        self.defaultHeaders = headers
        var postHeaders = headers
        postHeaders.updateValue(HttpClient.JSON, forKey: HttpClient.CONTENT_TYPE)
        self.postHeaders = postHeaders
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
    
    func picsPostParsed<T>(_ resource: String, data: Data, parse: @escaping (AnyObject) throws -> T, f: @escaping (T) -> Void, onError: @escaping (AppError) -> Void) {
        picsPost(resource, payload: data, f: {
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
            onResponse: { (data, response) -> Void in
                self.responseHandler(resource, data: data, response: response, f: f, onError: onError)
        },
            onError: { (err) -> Void in
                onError(.networkFailure(err))
        })
    }
    
    func picsPost(_ resource: String, payload: Data, f: @escaping (Data) -> Void, onError: @escaping (AppError) -> Void) {
        let url = URL(string: resource, relativeTo: baseURL)!
        self.postData(
            url,
            headers: postHeaders,
            payload: payload,
            onResponse: { (data, response) -> Void in
                self.responseHandler(resource, data: data, response: response, f: f, onError: onError)
        },
            onError: { (err) -> Void in
                onError(.networkFailure(err))
        })
    }
    
    func responseHandler(_ resource: String, data: Data, response: HTTPURLResponse, f: (Data) -> Void, onError: (AppError) -> Void) {
        let statusCode = response.statusCode
        let isStatusOK = (statusCode >= 200) && (statusCode < 300)
        if isStatusOK {
//            log.info("Response to '\(resource)' received with status '\(statusCode)'.")
            f(data)
        } else {
            log.error("Request to '\(resource)' failed with status '\(statusCode)'.")
            var errorMessage: String? = nil
            if let json = Json.asJson(data) as? NSDictionary {
                errorMessage = json[JsonError.Key] as? String
            }
            onError(.responseFailure(ResponseDetails(resource: resource, code: statusCode, message: errorMessage)))
        }
    }
    
    func onRequestError(_ data: Data, error: NSError) -> Void {
        log.error("Error: \(data)")
    }
}
