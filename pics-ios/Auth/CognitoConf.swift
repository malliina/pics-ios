import Foundation

class CognitoConf {
    static let PoolKey = "PicsPool"
    
    let clientId: String
    let userPoolId: String
    
    init(clientId: String, userPoolId: String) {
        self.clientId = clientId
        self.userPoolId = userPoolId
    }
    
    static func readOrThrow(key: String, dict: [String: AnyObject]) throws -> String {
        guard let value = dict[key] as? String else { throw CognitoError.invalidConf(message: "Missing or invalid \(key)") }
        return value
    }
    
    static func read() throws -> CognitoConf {
        if let path = Bundle.main.path(forResource: "Credentials", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            let clientId = try CognitoConf.readOrThrow(key: "CognitoClientId", dict: dict)
            let userPoolId = try CognitoConf.readOrThrow(key: "CognitoUserPoolId", dict: dict)
            return CognitoConf(clientId: clientId, userPoolId: userPoolId)
        } else {
            throw CognitoError.invalidConf(message: "Missing or invalid Credentials.plist")
        }
    }
}

enum CognitoError: Error {
    case invalidConf(message: String)
}
