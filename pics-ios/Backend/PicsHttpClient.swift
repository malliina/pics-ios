import Foundation
import AWSCognitoIdentityProvider

class PicsHttpClient: HttpClient {
    private let log = LoggerFactory.shared.network(PicsHttpClient.self)
    let baseURL: URL
    private var defaultHeaders: [String: String]
    private let postSpecificHeaders: [String: String]
    
    var postHeaders: [String: String] { return defaultHeaders.merging(postSpecificHeaders)  { (current, _) in current } }
    
    static let PicsVersion10 = "application/vnd.pics.v10+json"
    static let ClientPicHeader = "X-Client-Pic"
    
    convenience init(accessToken: AWSCognitoIdentityUserSessionToken?) {
        if let accessToken = accessToken {
            self.init(baseURL: EnvConf.shared.baseUrl, authValue: PicsHttpClient.authValueFor(forToken: accessToken))
        } else {
            self.init(baseURL: EnvConf.shared.baseUrl, authValue: nil)
        }
    }
    
    init(baseURL: URL, authValue: String?) {
        self.baseURL = baseURL
        if let authValue = authValue {
            self.defaultHeaders = [
                HttpClient.authorization: authValue,
                HttpClient.accept: PicsHttpClient.PicsVersion10
            ]
        } else {
            self.defaultHeaders = [
                HttpClient.accept: PicsHttpClient.PicsVersion10
            ]
        }
        self.postSpecificHeaders = [
            HttpClient.contentType: HttpClient.json
        ]
    }
    
    static func authValueFor(forToken: AWSCognitoIdentityUserSessionToken) -> String {
        "Bearer \(forToken.tokenString)"
    }
    
    func pingAuth() async throws -> Version {
        try await picsGetParsed("/ping", Version.self)
    }
    
    func picsGetParsed<T: Decodable>(_ resource: String, _ to: T.Type) async throws -> T {
        let response = try await picsGet(resource)
        return try parseAs(response: response, to)
    }
    
    func picsPostParsed<T: Decodable>(_ resource: String, data: Data, clientKey: ClientKey, _ to: T.Type) async throws -> T {
        let response = try await picsPost(resource, payload: data, clientKey: clientKey)
        return try self.parseAs(response: response, to)
    }
    
    private func parseAs<T: Decodable>(response: HttpResponse, _ to: T.Type) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(to, from: response.data)
    }
    
    func picsGet(_ resource: String) async throws -> HttpResponse {
        let url = urlFor(resource: resource)
        return try await statusChecked(response: self.get(url, headers: defaultHeaders))
    }
    
    func picsPost(_ resource: String, payload: Data, clientKey: ClientKey) async throws -> HttpResponse {
        let url = urlFor(resource: resource)
        return try await statusChecked(response: self.postData(url, headers: headersFor(clientKey: clientKey), payload: payload))
    }
    
    func picsDelete(_ resource: String) async throws -> HttpResponse {
        let url = URL(string: resource, relativeTo: baseURL)!
        return try await statusChecked(response: self.delete(url, headers: defaultHeaders))
    }
    
    func modify(key: ClientKey, access: AccessValue) async throws -> HttpResponse {
        let req = try build(path: "/pics/\(key)", method: HttpClient.post, body: ModifyBody(access: access))
        return try await make(request: req)
    }
    
    func urlFor(resource: String) -> URL {
        URL(string: resource, relativeTo: baseURL)!
    }
    
    func headersFor(clientKey: ClientKey) -> [String: String] {
        postHeaders.merging([PicsHttpClient.ClientPicHeader: clientKey.key]) { (current, _) in current }
    }
    
    func build<T: Encodable>(path: String, method: String, body: T? = nil) throws -> URLRequest {
        let headers = method == HttpClient.get ? defaultHeaders : postHeaders
        let url = urlFor(resource: path)
        if let body = body {
            let encoder = JSONEncoder()
            let data = try encoder.encode(body)
            return buildRequestWithBody(url: url, httpMethod: method, headers: postHeaders, body: data)
        } else {
            return buildRequest(url: url, httpMethod: method, headers: defaultHeaders)
        }
    }
    
    func make(request: URLRequest) async throws -> HttpResponse {
        let response = try await executeHttp(request, retryCount: 1)
        return try statusChecked(response: response)
    }
    
    func statusChecked(response: HttpResponse) throws -> HttpResponse {
        if response.isStatusOK {
            return response
        } else {
            let url = response.http.url?.absoluteString ?? "no url"
            self.log.error("Request to '\(url)' failed with status '\(response.statusCode)'.")
            let details = ResponseDetails(resource: url, code: response.statusCode, message: response.errors.first?.message)
            throw AppError.responseFailure(details)
        }
    }
    
    override func executeHttp(_ req: URLRequest, retryCount: Int = 0) async throws -> HttpResponse {
        var r = req
        r.addValue("\(retryCount)", forHTTPHeaderField: "X-Retry")
        let response = try await super.executeHttp(r)
        if retryCount == 0 && response.statusCode == 401 && response.isTokenExpired {
            let userInfo = try await Tokens.shared.retrieveUserInfoAsync()
            self.updateToken(token: userInfo.token)
            r.setValue(PicsHttpClient.authValueFor(forToken: userInfo.token), forHTTPHeaderField: HttpClient.authorization)
            return try await self.executeHttp(r, retryCount: retryCount + 1)
        } else {
            return response
        }
    }
    
    func handleError(error: AppError) {
        log.error(error.describe)
    }
    
    func updateToken(token: AWSCognitoIdentityUserSessionToken?) {
        if let token = token {
            self.defaultHeaders.updateValue(PicsHttpClient.authValueFor(forToken: token), forKey: HttpClient.authorization)
        } else {
            self.defaultHeaders.removeValue(forKey: HttpClient.authorization)
        }
    }
    
    func onRequestError(_ data: Data, error: NSError) -> Void {
        log.error("Error: \(data)")
    }
}
