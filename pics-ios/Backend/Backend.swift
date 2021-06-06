//
//  Backend.swift
//  pics-ios
//
//  Created by Michael Skogberg on 10/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

class Backend {
    static let shared = Backend(EnvConf.shared.baseUrl)
    
    let library: PicsLibrary
    let socket: PicsSocket
    
    init(_ baseUrl: URL) {
        self.library = PicsLibrary(http: PicsHttpClient(accessToken: nil))
        self.socket = PicsSocket(authValue: nil)
    }
    
    func updateToken(new token: AWSCognitoIdentityUserSessionToken?) {
        library.http.updateToken(token: token)
        socket.updateAuthHeader(with: authValue(token: token))
    }
    
    private func authValue(token: AWSCognitoIdentityUserSessionToken?) -> String? {
        guard let token = token else { return nil }
        return PicsHttpClient.authValueFor(forToken: token)
    }
}
