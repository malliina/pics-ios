//
//  WebSocket.swift
//  pics-ios
//
//  Created by Michael Skogberg on 5.6.2021.
//  Copyright © 2021 Michael Skogberg. All rights reserved.
//

import Foundation

protocol WebSocketMessageDelegate {
    func onMessage(_ msg: String)
}

class WebSocket: NSObject, URLSessionWebSocketDelegate {
    private let log = LoggerFactory.shared.network(WebSocket.self)
    let baseURL: URL
    fileprivate var request: URLRequest
    private var task: URLSessionWebSocketTask
    var isConnected = false
    
    init(baseURL: URL, headers: [String: String]) {
        self.baseURL = baseURL
        self.request = URLRequest(url: self.baseURL)
        for (key, value) in headers {
            self.request.addValue(value, forHTTPHeaderField: key)
        }
        task = URLSession.shared.webSocketTask(with: request)
    }
    
    func updateAuthHeaderValue(newValue: String?) {
        request.setValue(newValue, forHTTPHeaderField: HttpClient.authorization)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        log.info("Connected to \(baseURL).")
        isConnected = true
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        log.info("Disconnected from \(baseURL).")
        isConnected = false
    }
    
    private func receive() {
      task.receive { result in
        switch result {
        case .success(let message):
          switch message {
          case .data(let data):
            self.log.info("Data received \(data)")
          case .string(let text):
            self.log.info("Text received \(text)")
          }
        case .failure(let error):
            self.log.error("Error when receiving \(error)")
        }
        
        self.receive()
      }
    }
    
    func close() {
      let reason = "Closing connection".data(using: .utf8)
      task.cancel(with: .goingAway, reason: reason)
    }
}
