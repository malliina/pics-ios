//
//  HttpClient.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class HttpClient {
    private let log = LoggerFactory.shared.network(HttpClient.self)
    static let JSON = "application/json", CONTENT_TYPE = "Content-Type", ACCEPT = "Accept", GET = "GET", POST = "POST", AUTHORIZATION = "Authorization", BASIC = "Basic"
    
    static func basicAuthValue(_ username: String, password: String) -> String {
        let encodable = "\(username):\(password)"
        let encoded = encodeBase64(encodable)
        return "\(HttpClient.BASIC) \(encoded)"
    }
    
    static func authHeader(_ word: String, unencoded: String) -> String {
        let encoded = HttpClient.encodeBase64(unencoded)
        return "\(word) \(encoded)"
    }
    
    static func encodeBase64(_ unencoded: String) -> String {
        return unencoded.data(using: String.Encoding.utf8)!.base64EncodedString(options: NSData.Base64EncodingOptions())
    }
    
    let session: URLSession
    
    init() {
        self.session = URLSession.shared
    }
    
    func get(_ url: URL, headers: [String: String] = [:], onResponse: @escaping (Data, HTTPURLResponse) -> Void, onError: @escaping (RequestFailure) -> Void) {
        get(url, headers: headers) { (data, response, error) -> Void in
            if let error = error {
                onError(RequestFailure(url: url, code: error._code, data: data))
            } else if let httpResponse = response as? HTTPURLResponse, let data = data {
                onResponse(data, httpResponse)
            } else {
                self.log.error("Unable to interpret HTTP response to URL \(url.absoluteString)")
            }
        }
    }
    
    func get(_ url: URL, headers: [String: String] = [:], completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        executeRequest(
            buildRequest(url: url, httpMethod: HttpClient.GET, headers: headers, body: nil),
            completionHandler: completionHandler)
    }
    
    func postJSON(_ url: URL, headers: [String: String] = [:], payload: [String: AnyObject], onResponse: @escaping (Data, HTTPURLResponse) -> Void, onError: @escaping (RequestFailure) -> Void) {
        postData(url, headers: headers, payload: try? JSONSerialization.data(withJSONObject: payload, options: []), onResponse: onResponse, onError: onError)
    }
    
    func postData(_ url: URL, headers: [String: String] = [:], payload: Data?, onResponse: @escaping (Data, HTTPURLResponse) -> Void, onError: @escaping (RequestFailure) -> Void) {
        postGeneric(url, headers: headers, payload: payload) { (data, response, error) -> Void in
            self.log.info("Request to \(url) complete.")
            if let error = error {
                self.log.info("Request to \(url) failed: '\(error)'.")
                onError(RequestFailure(url: url, code: error._code, data: data))
            } else if let httpResponse = response as? HTTPURLResponse, let data = data {
                self.log.info("Request to \(url) succeeded with a response.")
                onResponse(data, httpResponse)
            } else {
                self.log.error("Unable to interpret HTTP response to URL \(url.absoluteString)")
            }
        }
    }
    
    func postGeneric(_ url: URL, headers: [String: String] = [:], payload: Data?, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        let req = buildRequest(url: url, httpMethod: HttpClient.POST, headers: headers, body: payload)
        executeRequest(req, completionHandler: completionHandler)
    }
    
    func executeRequest(
        _ req: URLRequest,
        completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        let task = session.dataTask(with: req, completionHandler: completionHandler)
        task.resume()
    }
    
    func buildRequest(url: URL, httpMethod: String, headers: [String: String], body: Data?) -> URLRequest {
        var req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 3600)
        req.httpMethod = httpMethod
        for (key, value) in headers {
            req.addValue(value, forHTTPHeaderField: key)
        }
        if let body = body {
            req.httpBody = body
        }
        return req
    }
}
