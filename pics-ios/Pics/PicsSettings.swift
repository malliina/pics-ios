//
//  PicsSettings.swift
//  pics-ios
//
//  Created by Michael Skogberg on 27/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation

class PicsSettings {
    static let shared = PicsSettings()
    
    let IsPublic = "is_private"
    let PicsKey = "pics"
    
    let prefs = UserDefaults.standard
    
    var isPrivate: Bool {
        get { return prefs.bool(forKey: IsPublic) }
        set (newValue) {
            prefs.set(newValue, forKey: IsPublic)
            // Clears any private pic cache when we switch to public mode
            if !newValue {
                clearPics()
            }
        }
    }
    
    var localPics: [Picture] {
        get { return loadPics() }
        set (newValue) { savePics(pics: newValue) }
    }
    
    func clearPics() {
        localPics = []
    }
    
    private func savePics(pics: [Picture]) {
        let jsons = pics.map { PicMeta.write(pic: $0.meta) } as AnyObject
        let json = [ PicMeta.Pics : jsons ]
        let stringified = Json.stringifyObject(json)
        prefs.set(stringified, forKey: PicsKey)
    }
    
    private func loadPics() -> [Picture] {
        guard let stringified = prefs.string(forKey: PicsKey) else { return [] }
        guard let asJson = Json.asJson(stringified) else { return [] }
        do {
            return try PicsLibrary.parsePics(obj: asJson).map({ (p) in Picture(meta: p) })
        } catch {
            return []
        }
    }
}
