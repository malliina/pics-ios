//
//  LocalPics.swift
//  pics-ios
//
//  Created by Michael Skogberg on 16/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class LocalPics {
    private let log = LoggerFactory.shared.pics("Pics", category: LocalPics.self)
    
    static let shared = LocalPics()
    
    let dir: URL
    
    init() {
        let dirString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/pics"
        dir = URL(fileURLWithPath: dirString, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }
    
    func saveAsJpg(data: Data) throws -> URL {
        let name = "pic-\(Double(Date().timeIntervalSinceNow)).jpg"
        let dest = dir.appendingPathComponent(name)
        try data.write(to: dest)
        log.info("Saved pic as \(name)")
        return dest
    }
}