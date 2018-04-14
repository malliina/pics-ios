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
        let smallFiles = try! FileManager.default.contentsOfDirectory(at: small, includingPropertiesForKeys: [URLResourceKey.creationDateKey, URLResourceKey.isRegularFileKey])
        log.info("Local small files: \(smallFiles.count).")
        let sorted = smallFiles.filter { $0.isFile }.sorted { (file1, file2) -> Bool in
            file1.created > file2.created
        }
//        sorted.forEach { (url) in
//            let values = try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey])
//            if let values = values, let size = values.fileSize {
//                log.info("Size: \(size)")
////                log.info("Created: \(created.timeIntervalSince1970)")
//            }
//        }
        let removed = maintenance(smallFiles: sorted.drop(1000))
        if removed.count > 0 {
            let removedString = removed.map { $0.path }.mkString(", ")
            log.info("Maintenance complete. Removed \(removed.count) files: \(removedString).")
        }
    }
    
    func createdFor(url: URL) -> Date {
        if let values = try? url.resourceValues(forKeys: [URLResourceKey.creationDateKey]), let created = values.creationDate {
            return created
        } else {
            return Date.distantPast
        }
    }
    
    func maintenance(smallFiles: [URL]) -> [URL] {
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [URLResourceKey.creationDateKey, URLResourceKey.isRegularFileKey], options: .skipsHiddenFiles)) ?? []
        log.info("Local original files: \(files.count).")
        let oneMonthAgo = Date(timeIntervalSinceNow: -3600 * 24 * 30)
        // Deletes over one month old original files - they should have been uploaded by now
        let locallyTaken = files.flatMapOpt { (url) -> URL? in
            if !fileManager.isDirectory(url: url) && url.lastPathComponent.startsWith(localPrefix) && url.created < oneMonthAgo {
                guard let _ = try? fileManager.removeItem(at: url) else { return nil }
                return url
            } else {
                return nil
            }
        }
        let smaller = remove(smallFiles: smallFiles)
        return locallyTaken + smaller
    }
    
    func remove(smallFiles: [URL]) -> [URL] {
        return smallFiles.flatMapOpt { (smallUrl) -> URL? in
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

extension URL {
    var created: Date {
        if let values = try? self.resourceValues(forKeys: [URLResourceKey.creationDateKey]), let created = values.creationDate {
            return created
        } else {
            return Date.distantPast
        }
    }
    
    var isFile: Bool {
        if let values = try? self.resourceValues(forKeys: [URLResourceKey.isRegularFileKey]), let isRegularFile = values.isRegularFile {
            return isRegularFile
        } else {
            return false
        }
    }
}
