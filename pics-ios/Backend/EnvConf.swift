//
//  EnvConf.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class EnvConf {
    static let DevBaseUrl = URL(string: "http://10.0.0.21:9000")!
    static let ProdBaseUrl = URL(string: "https://pics.malliina.com")!
    static let BaseUrl = ProdBaseUrl
}
