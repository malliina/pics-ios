import Foundation
import AWSCognitoIdentityProvider

protocol PicsDelegate {
    func onPics(pics: [PicMeta]) async
    func onPicsRemoved(keys: [ClientKey]) async
    func onProfile(info: ProfileInfo) async
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
    
    func on(message: String) async {
        guard let data = message.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            log.error("Cannot read message data from: '\(message)'.")
            return
        }
        let decoder = JSONDecoder()
        log.info("Got message \(message)")
        do {
            guard let delegate = delegate else { return }
            let event = try decoder.decode(KeyedEvent.self, from: data)
            switch event.event {
            case "ping":
                return
            case "added":
                await delegate.onPics(pics: try decoder.decode(PicsResponse.self, from: data).pics)
                break
            case "removed":
                await delegate.onPicsRemoved(keys: try decoder.decode(ClientKeys.self, from: data).keys)
                break
            case "welcome":
                await delegate.onProfile(info: try decoder.decode(ProfileInfo.self, from: data))
                break
            default:
                throw JsonError.invalid("Unknown event: '\(event)'.", message)
            }
        } catch let err {
            log.error("Parse error for received message: '\(message)'. Error: '\(err)'.")
        }
    }
}
