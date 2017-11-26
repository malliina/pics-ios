//
//  JsonError.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

enum JsonError: Error {
    case notJson(Data)
    case missing(String)
    case invalid(String, Any)
}
