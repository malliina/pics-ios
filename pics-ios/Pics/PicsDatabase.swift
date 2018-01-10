//
//  PicsDatabase.swift
//  pics-ios
//
//  Created by Michael Skogberg on 09/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation

class PicsDatabase {
    static let shared = PicsDatabase()
    
    let prefs = UserDefaults.standard
    
    var pics: [Picture]
    
    static let PicsKey = "pics"
    
    init() {
        pics = PicsDatabase.loadFromDisk()
    }
    
    func savePics(ps: [Picture]) {
        pics = ps
        save()
    }
    
    func save() {
        let jsons = pics.map { PicMeta.write(pic: $0.meta) } as AnyObject
        let json = [ PicMeta.Pics : jsons ]
        let stringified = Json.stringifyObject(json)
        prefs.set(stringified, forKey: PicsDatabase.PicsKey)
    }
    
    static func loadFromDisk() -> [Picture] {
        guard let stringified = UserDefaults.standard.string(forKey: PicsKey) else { return [] }
        guard let asJson = Json.asJson(stringified) else { return [] }
        do {
            return try PicsLibrary.parsePics(obj: asJson).map({ (p) in Picture(meta: p) })
        } catch {
            return []
        }
    }
    
    func clear() {
        savePics(ps: [])
    }
}
