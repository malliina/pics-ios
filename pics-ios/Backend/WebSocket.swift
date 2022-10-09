//
//  WebSocket.swift
//  pics-ios
//
//  Created by Michael Skogberg on 5.6.2021.
//  Copyright © 2021 Michael Skogberg. All rights reserved.
//

import Foundation

protocol WebSocketMessageDelegate {
    func on(message: String) async
}

class WebSocket: NSObject, URLSessionWebSocketDelegate {
    private let log = LoggerFactory.shared.network(WebSocket.self)
    let sessionConfiguration: URLSessionConfiguration
    let baseURL: URL
    var urlString: String { baseURL.absoluteString }
    private var session: URLSession? = nil
    fileprivate var request: URLRequest
    private var task: URLSessionWebSocketTask?
    private var isConnected = false
    var delegate: WebSocketMessageDelegate? = nil
    private var receiveTask: Task<(), Never>? = nil
    
    init(baseURL: URL, headers: [String: String]) {
        self.baseURL = baseURL
        self.request = URLRequest(url: self.baseURL)
        for (key, value) in headers {
            self.request.addValue(value, forHTTPHeaderField: key)
        }
        sessionConfiguration = URLSessionConfiguration.default
        super.init()
        sessionConfiguration.httpAdditionalHeaders = headers
    }
    
    private func prepTask() -> URLSessionWebSocketTask {
        let s = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue())
        session = s
        let socketTask = s.webSocketTask(with: request)
        task = socketTask
        return socketTask
    }
    
//    func reconnect() {
//        if task != nil {
//            disconnect()
//        }
//        connect()
//    }
    
    func connect() {
        let socketTask = prepTask()
        let hasToken = request.value(forHTTPHeaderField: HttpClient.authorization) != nil
        let describe = hasToken ? "with token" : "without token"
        log.info("Connecting to \(urlString) \(describe)...")
        socketTask.resume()
    }
    
    /** Fucking Christ Swift sucks. "Authorization" is a "reserved header" where iOS chooses not to send its value even when set, it seems. So we set it in two ways anyway and hope that either works: both to the request and the session configuration.
     */
    func updateAuthHeader(newValue: String?) {
        request.setValue(newValue, forHTTPHeaderField: HttpClient.authorization)
        if let value = newValue {
            sessionConfiguration.httpAdditionalHeaders = [HttpClient.authorization: value]
        } else {
            sessionConfiguration.httpAdditionalHeaders = [:]
        }
        _ = prepTask()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        log.info("Connected to \(urlString).")
        isConnected = true
        receiveTask = Task { await receive() }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        log.info("Disconnected from \(urlString).")
        isConnected = false
    }
    
    private func receive() async {
        guard let task = task else {
            log.error("No task, cannot receive messages.")
            return
        }
        do {
            switch try await task.receive() {
            case .data(let data):
                self.log.info("Data received \(data)")
            case .string(let text):
//                self.log.info("Text received \(text)")
                await self.delegate?.on(message: text)
                await self.receive()
            default:
                ()
            }
        } catch let error {
            self.log.error("Error when receiving \(error)")
        }
    }
    
    func disconnect() {
        self.log.info("Disconnecting from \(urlString).")
        let reason = "Closing connection".data(using: .utf8)
        receiveTask?.cancel()
        task?.cancel(with: .goingAway, reason: reason)
    }
}
