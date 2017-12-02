//
//  PicsHttpClient.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class PicsHttpClient: HttpClient {
    private let log = LoggerFactory.shared.network("PicsHttpClient")
    let baseURL: URL
    let defaultHeaders: [String: String]
    let postHeaders: [String: String]
    
//    static let PicsVersion10 = "application/vnd.pics.v10+json"
    static let PicsVersion10 = "application/json"
    
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
    
    func picsPost(_ resource: String, payload: [String: AnyObject], f: @escaping (Data) -> Void, onError: @escaping (AppError) -> Void) {
        let url = URL(string: resource, relativeTo: baseURL)!
        self.postJSON(
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
            f(data)
        } else {
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
