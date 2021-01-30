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
                HttpClient.authorization: authValue,
                HttpClient.accept: PicsHttpClient.PicsVersion10
            ]
        } else {
            headers = [
                HttpClient.accept: PicsHttpClient.PicsVersion10
            ]
        }
        super.init(baseURL: baseURL, headers: headers)
        Tokens.shared.addDelegate(self)
    }
    
    func onAccessToken(_ token: AWSCognitoIdentityUserSessionToken) {
        updateAuthHeaderValue(newValue: PicsHttpClient.authValueFor(forToken: token))
    }
    
    func send<T: Encodable>(_ json: T) -> ErrorMessage? {
        if let socket = socket {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(json)
                guard let asString = String(data: data, encoding: .utf8) else {
                    return ErrorMessage("JSON-to-String conversion failed.")
                }
                socket.send(asString)
                //Log.info("Sent \(payload) to \(baseURL))")
                return nil
            } catch let err {
                return failWith("Unable to send payload, encountered non-JSON payload: '\(err)'.")
            }
        } else {
            return failWith("Unable to send payload, socket not available.")
        }
    }
    
    func failWith(_ message: String) -> ErrorMessage {
        log.error(message)
        return ErrorMessage(message)
    }
    
    override func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if let message = message as? String {
            guard let data = message.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
                log.error("Cannot read message data from: '\(message)'.")
                return
            }
            let decoder = JSONDecoder()
            log.info("Got message \(message)")
            do {
                let event = try decoder.decode(KeyedEvent.self, from: data)
                switch event.event {
                case "ping":
                    return
                case "added":
                    delegate?.onPics(pics: try decoder.decode(PicsResponse.self, from: data).pics)
                    break
                case "removed":
                    delegate?.onPicsRemoved(keys: try decoder.decode(ClientKeys.self, from: data).keys)
                    break
                case "welcome":
                    delegate?.onProfile(info: try decoder.decode(ProfileInfo.self, from: data))
                    break
                default:
                    throw JsonError.invalid("Unknown event: '\(event)'.", message)
                }
            } catch let err {
                log.error("Parse error for received message: '\(message)'. Error: '\(err)'.")
            }
        } else {
            log.error("Received a non-string JSON message.")
        }
    }
}
