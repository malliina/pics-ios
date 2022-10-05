//
//  PicsSocket.swift
//  pics-ios
//
//  Created by Michael Skogberg on 25/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

protocol PicsDelegate {
    func onPics(pics: [PicMeta])
    func onPicsRemoved(keys: [ClientKey])
    func onProfile(info: ProfileInfo)
}

class PicsSocket: TokenDelegate, WebSocketMessageDelegate {
    private let log = LoggerFactory.shared.network(PicsSocket.self)
    private let socket: WebSocket
    var delegate: PicsDelegate? = nil
    
    convenience init(authValue: String?) {
        self.init(baseURL: URL(string: "/sockets", relativeTo: EnvConf.shared.baseSocketUrl)!, authValue: authValue)
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
        socket = WebSocket(baseURL: baseURL, headers: headers)
        socket.delegate = self
        Tokens.shared.addDelegate(self)
    }
    
    func reconnect() {
//        let token = try await Tokens.shared.retrieveUserInfoAsync(cancellationToken: nil)
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func onAccessToken(_ token: AWSCognitoIdentityUserSessionToken) {
        socket.updateAuthHeader(newValue: PicsHttpClient.authValueFor(forToken: token))
    }
    
    func updateAuthHeader(with value: String?) {
        socket.updateAuthHeader(newValue: value)
    }
    
    func failWith(_ message: String) -> ErrorMessage {
        log.error(message)
        return ErrorMessage(message)
    }
    
    func on(message: String) {
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
    }
}
