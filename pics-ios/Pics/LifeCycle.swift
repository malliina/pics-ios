//
//  LifeCycle.swift
//  pics-ios
//
//  Created by Michael Skogberg on 10/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation

class LifeCycle {
    static let shared = LifeCycle()
    
    var renderer: PicsRenderer? = nil
}
