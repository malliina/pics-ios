//
//  LocalPics.swift
//  pics-ios
//
//  Created by Michael Skogberg on 16/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class LocalPics {
    private static let logger = LoggerFactory.shared.pics(LocalPics.self)
    private var log: Logger { return LocalPics.logger }
    
    static let shared = LocalPics()
    
    let dir: URL
    let small: URL
    
    let localPrefix = "pic-"
    
    init() {
        let dirString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/pics"
        dir = URL(fileURLWithPath: dirString, isDirectory: true)
        small = dir.appendingPathComponent("small", isDirectory: true)
        LocalPics.createDirectory(at: dir)
        LocalPics.createDirectory(at: small)
        let smallFiles = try! FileManager.default.contentsOfDirectory(at: small, includingPropertiesForKeys: nil)
        log.info("Local small files: \(smallFiles.count)")
        let removed = maintenance(keys: [])
        if removed.count > 0 {
            let removedString = removed.map { $0.path }.mkString(", ")
            log.info("Maintenance complete. Removed \(removed.count) files: \(removedString).")
        }
    }
    
    func maintenance(keys: [String]) -> [URL] {
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let locallyTaken = files.flatMapOpt { (url) -> URL? in
            if !fileManager.isDirectory(url: url) && url.lastPathComponent.startsWith(localPrefix) {
                guard let _ = try? fileManager.removeItem(at: url) else { return nil }
                return url
            } else {
                return nil
            }
        }
        let smaller = remove(keys: keys)
        return locallyTaken + smaller
        
    }
    
    func remove(keys: [String]) -> [URL] {
        return keys.flatMapOpt { (key) -> URL? in
            let smallUrl = fileFor(key: key, dir: small)
            let exists = (try? smallUrl.checkResourceIsReachable()) ?? false
            if exists {
                guard let _ = try? FileManager.default.removeItem(at: smallUrl) else { return nil }
                return smallUrl
            } else {
                return nil
            }
        }
    }
    
    func readSmall(key: String) -> Data? {
        let src = fileFor(key: key, dir: small)
        guard let exists = try? src.checkResourceIsReachable() else { return nil }
        return exists ? try? Data(contentsOf: src) : nil
    }
    
    func saveSmall(data: Data, key: String) -> URL? {
        let dest = fileFor(key: key, dir: small)
        let exists = (try? dest.checkResourceIsReachable()) ?? false
        if !exists {
//            log.info("Saving \(key) to \(dest)")
            let success = (try? data.write(to: dest)) != nil
            if success {
                log.info("Saved \(key) locally to \(dest)")
                return dest
            } else {
                log.info("Failed to write \(key) to \(dest)")
                return nil
            }
        } else {
            log.info("Already exists: \(key)")
            return nil
        }
    }
    
    func fileFor(key: String, dir: URL) -> URL {
        return dir.appendingPathComponent(key, isDirectory: false)
    }
    
    static func createDirectory(at dir: URL) {
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        logger.info("Created \(dir)")
    }
    
    func saveAsJpg(data: Data) throws -> URL {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let name = "\(localPrefix)\(millis).jpg"
        let dest = urlFor(name: name)
        try data.write(to: dest)
        log.info("Saved \(name) to \(dest)")
        return dest
    }
    
    func urlFor(name: String) -> URL {
        return dir.appendingPathComponent(name)
    }
}

extension FileManager {
    func isDirectory(url: URL) -> Bool {
        var isDirectory: ObjCBool = ObjCBool(false)
        self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}
