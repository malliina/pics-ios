//
//  PicsService.swift
//  pics-ios
//
//  Created by Michael Skogberg on 22/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class PicsLibrary {
    func load(from: Int, limit: Int, onResult: ([String]) -> Void) {
        let rows: [Int] = Array(1..<limit+1)
        
        onResult(rows.map({ (i) -> String in
            "\(i)"
        }))
    }
}
