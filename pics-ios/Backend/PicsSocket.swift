//
//  PicsSocket.swift
//  pics-ios
//
//  Created by Michael Skogberg on 25/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import SocketRocket
import AWSCognitoIdentityProvider

protocol PicsDelegate {
    func onPics(pics: [PicMeta])
    func onPicsRemoved(keys: [ClientKey])
    func onProfile(info: ProfileInfo)
}

class PicsSocket: SocketClient, TokenDelegate {
    private let log = LoggerFactory.shared.network(PicsSocket.self)
    
    var delegate: PicsDelegate? = nil
    
    convenience init(authValue: String?) {
        self.init(baseURL: URL(string: "/sockets", relativeTo: EnvConf.BaseUrl)!, authValue: authValue)
    }
    
    init(baseURL: URL, authValue: String?) {
        var headers: [String: String] = [:]
        if let authValue = authValue {
            headers = [
                HttpClient.AUTHORIZATION: authValue,
                HttpClient.ACCEPT: PicsHttpClient.PicsVersion10
            ]
        } else {
            headers = [
                HttpClient.ACCEPT: PicsHttpClient.PicsVersion10
            ]
        }
        super.init(baseURL: baseURL, headers: headers)
        Tokens.shared.addDelegate(self)
    }
    
    func onAccessToken(_ token: AWSCognitoIdentityUserSessionToken) {
        updateAuthHeaderValue(newValue: PicsHttpClient.authValueFor(forToken: token))
    }
    
    func send(_ dict: [String: AnyObject]) -> ErrorMessage? {
        if let socket = socket {
            if let payload = Json.stringifyObject(dict, prettyPrinted: false) {
                socket.send(payload)
                //Log.info("Sent \(payload) to \(baseURL))")
                return nil
            } else {
                return failWith("Unable to send payload, encountered non-JSON payload: \(dict)")
            }
        } else {
            return failWith("Unable to send payload, socket not available.")
        }
    }
    
    func failWith(_ message: String) -> ErrorMessage {
        log.error(message)
        return ErrorMessage(message: message)
    }
    
    override func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if let message = message as? String {
//            log.info("Got message \(message)")
            do {
                let dict = try Json.asJsonDict(message)
                let event: String = try Json.readOrFail(dict, "event")
                if event == "ping" {
                    return
                } else if event == "added" {
                    let pics = try PicsLibrary.parsePics(obj: dict)
                    delegate?.onPics(pics: pics)
                } else if event == "removed" {
                    let keys = try PicsLibrary.parseKeys(obj: dict)
                    delegate?.onPicsRemoved(keys: keys)
                } else if event == "welcome" {
                    let profile = try ProfileInfo.parse(dict)
                    delegate?.onProfile(info: profile)
                } else {
                    throw JsonError.invalid("Unknown event: '\(event)'.", message)
                }
            } catch let error as JsonError {
                log.error("JSON parse error. \(error) for message: '\(message)'.")
            } catch _ {
                log.error("Unknown parse error for received message: '\(message)'.")
            }
        } else {
            log.error("Received a non-string JSON message.")
        }
    }
}
