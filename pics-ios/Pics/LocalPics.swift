//
//  LocalPics.swift
//  pics-ios
//
//  Created by Michael Skogberg on 16/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class LocalPics {
    private let log = LoggerFactory.shared.pics(LocalPics.self)
    
    static let shared = LocalPics()
    
    let dir: URL
    
    init() {
        let dirString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/pics"
        dir = URL(fileURLWithPath: dirString, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let files = try! FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        files.forEach { (url) in
            log.info("\(url)")
        }
        log.info("Local pics: \(files.count)")
    }
    
    func saveAsJpg(data: Data) throws -> URL {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let name = "pic-\(millis).jpg"
        let dest = urlFor(name: name)
        try data.write(to: dest)
        log.info("Saved \(name) to \(dest)")
        return dest
    }
    
    func urlFor(name: String) -> URL {
        return dir.appendingPathComponent(name)
    }
}
