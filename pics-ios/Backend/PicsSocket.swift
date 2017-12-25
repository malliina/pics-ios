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
}

class PicsSocket: SocketClient, TokenDelegate {
    private let log = LoggerFactory.shared.network(PicsSocket.self)
    
    var delegate: PicsDelegate? = nil
    
    static let ProdUrl = URL(string: "https://pics.malliina.com/sockets")!
    static let DevUrl = URL(string: "http://10.0.0.21:9000/sockets")!
    
    convenience init(authValue: String) {
        self.init(baseURL: PicsSocket.DevUrl, authValue: authValue)
    }
    
    init(baseURL: URL, authValue: String) {
        let headers = [
            HttpClient.AUTHORIZATION: authValue,
            HttpClient.ACCEPT: PicsHttpClient.PicsVersion10
        ]
        
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
            log.info("Got message \(message)")
            if let dict = Json.asJson(message)  {
                do {
                    if try PicsLibrary.isPing(obj: dict) { return }
                    let pics = try PicsLibrary.parsePics(obj: dict)
                    delegate?.onPics(pics: pics)
                } catch let error as JsonError {
                    self.log.error("JSON parse error. \(error)")
                } catch _ {
                    log.error("Unknown parse error for received message.")
                }
            } else {
                log.error("Received a non-JSON message.")
            }
        } else {
            log.error("Received a non-string JSON message.")
        }
    }
}
