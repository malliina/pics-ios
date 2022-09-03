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
    static let json = "application/json", contentType = "Content-Type", accept = "Accept", delete = "DELETE", get = "GET", post = "POST", authorization = "Authorization", basic = "Basic"
    
    static func basicAuthValue(_ username: String, password: String) -> String {
        let encodable = "\(username):\(password)"
        let encoded = encodeBase64(encodable)
        return "\(HttpClient.basic) \(encoded)"
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
    
    func get(_ url: URL, headers: [String: String] = [:]) async throws -> HttpResponse {
        let req = buildRequest(url: url, httpMethod: HttpClient.get, headers: headers)
        return try await executeHttp(req)
    }
    
    func postJSON<T: Encodable>(_ url: URL, headers: [String: String] = [:], payload: T) async throws -> HttpResponse {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        return try await postData(url, headers: headers, payload: data)
    }
    
    func postData(_ url: URL, headers: [String: String] = [:], payload: Data) async throws -> HttpResponse {
        let req = buildRequestWithBody(url: url, httpMethod: HttpClient.post, headers: headers, body: payload)
        return try await executeHttp(req)
    }
    
    func delete(_ url: URL, headers: [String: String] = [:]) async throws -> HttpResponse {
        let req = buildRequest(url: url, httpMethod: HttpClient.delete, headers: headers)
        return try await executeHttp(req)
    }
    
    func executeHttp(_ req: URLRequest, retryCount: Int = 0) async throws -> HttpResponse {
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse {
            return HttpResponse(http: httpResponse, data: data)
        } else {
            throw AppError.simple("Non-HTTP response from \(req.url?.absoluteString ?? "no url").")
        }
    }
    
    func buildRequest(url: URL, httpMethod: String, headers: [String: String]) -> URLRequest {
        var req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 3600)
        let useCsrfHeader = httpMethod != HttpClient.get
        if useCsrfHeader {
            req.addCsrf()
        }
        req.httpMethod = httpMethod
        for (key, value) in headers {
            req.addValue(value, forHTTPHeaderField: key)
        }
        return req
    }
    
    func buildRequestWithBody(url: URL, httpMethod: String, headers: [String: String], body: Data) -> URLRequest {
        var req = buildRequest(url: url, httpMethod: httpMethod, headers: headers)
        req.httpBody = body
        return req
    }
    
//    func executeRequest(_ req: URLRequest, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) {
//        let task = session.dataTask(with: req, completionHandler: completionHandler)
//        task.resume()
//    }
}

extension URLRequest {
    mutating func addCsrf() {
        self.addValue("nocheck", forHTTPHeaderField: "Csrf-Token")
    }
}
