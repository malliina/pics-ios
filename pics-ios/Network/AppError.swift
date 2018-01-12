//
//  AppError.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

enum AppError {
    case parseError(JsonError)
    case responseFailure(ResponseDetails)
    case networkFailure(RequestFailure)
    case simpleError(ErrorMessage)
    case tokenError(Error)
    
    var describe: String { return AppError.stringify(self) }
    
    static func stringify(_ error: AppError) -> String {
        return AppErrorUtil.stringify(error)
    }
    
    static func simple(_ message: String) -> AppError {
        return AppError.simpleError(ErrorMessage(message: message))
    }
}

class AppErrorUtil {
    static func stringify(_ error: AppError) -> String {
        switch error {
        case .parseError(let json):
            switch json {
            case .missing(let key):
                return "Key not found: '\(key)'."
            case .invalid(let key, let actual):
                return "Invalid '\(key)' value: '\(actual)'."
            case .notJson( _):
                return "Invalid response format. Expected JSON."
            }
        case .responseFailure(let details):
            let code = details.code
            switch code {
            case 400:
                return "Bad request: \(details.resource)."
            case 401:
                return "Check your username/password."
            case 404:
                return "Resource not found: \(details.resource)."
            case 406:
                return "Please update this app to the latest version to continue. This version is no longer supported."
            default:
                if let message = details.message {
                    return "Error code: \(code), message: \(message)"
                } else {
                    return "Error code: \(code)."
                }
            }
        case .networkFailure( _):
            return "A network error occurred."
        case .tokenError(_):
            return "A network error occurred."
        case .simpleError(let message):
            return message.message
        }
    }
    
    static func stringifyDetailed(_ error: AppError) -> String {
        switch error {
        case .networkFailure(let request):
            return "Unable to connect to \(request.url.description), status code \(request.code)."
        default:
            return stringify(error)
        }
    }
}

class ResponseDetails {
    let resource: String
    let code: Int
    let message: String?
    
    init(resource: String, code: Int, message: String?) {
        self.resource = resource
        self.code = code
        self.message = message
    }
}

class RequestFailure {
    let url: URL
    let code: Int
    let data: Data?
    
    init(url: URL, code: Int, data: Data?) {
        self.url = url
        self.code = code
        self.data = data
    }
}

class ErrorMessage {
    let message: String
    
    init(message: String) {
        self.message = message
    }
}

class SingleError {
    let key: String
    let message: String
    
    init(key: String, message: String) {
        self.key = key
        self.message = message
    }
}

class HttpResponse {
    let http: HTTPURLResponse
    let data: Data
    
    var statusCode: Int { return http.statusCode }
    var isStatusOK: Bool { return statusCode >= 200 && statusCode < 300 }
    var json: NSDictionary? { return Json.asJson(data) as? NSDictionary }
    var errors: [SingleError] {
        get {
            if let json = json, let errors = json["errors"] as? [NSDictionary] {
                return errors.flatMap({ (dict) -> SingleError? in
                    if let key = dict["key"] as? String, let message = dict["message"] as? String {
                        return SingleError(key: key, message: message)
                    } else {
                        return nil
                    }
                })
            } else {
                return []
            }
        }
    }
    var isTokenExpired: Bool {
        return errors.contains { $0.key == "token_expired" }
    }
    
    init(http: HTTPURLResponse, data: Data) {
        self.http = http
        self.data = data
    }
}
