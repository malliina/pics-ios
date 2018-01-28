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
    static let PicsKey = "pics"
    let EulaAccepted = "eula_accepted"
    static let BlockedImageKeys = "blocked_keys"
    
    let prefs = UserDefaults.standard
    
    private var cachedPictures: [Picture] = PicsSettings.loadPics()
    private var blockedKeys: [String] = PicsSettings.loadBlocked()
    
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
    
    var isEulaAccepted: Bool {
        get { return prefs.bool(forKey: EulaAccepted) }
        set (newValue) { prefs.set(newValue, forKey: EulaAccepted) }
    }
    
    var blockedImageKeys: [String] {
        get { return blockedKeys }
        set (newValue) {
            blockedKeys = newValue
            prefs.set(newValue, forKey: PicsSettings.BlockedImageKeys)
        }
    }
    
    func block(key: String) {
        let blockedList = blockedImageKeys + [key]
        blockedImageKeys = blockedList
    }
    
    var localPics: [Picture] {
        get { return cachedPictures }
        set (newValue) {
            cachedPictures = newValue
            savePics(pics: newValue)
        }
    }
    
    func clearPics() {
        localPics = []
    }
    
    private func savePics(pics: [Picture]) {
        let jsons = pics.map { PicMeta.write(pic: $0.meta) } as AnyObject
        let json = [ PicMeta.Pics : jsons ]
        let stringified = Json.stringifyObject(json)
        prefs.set(stringified, forKey: PicsSettings.PicsKey)
    }
    
    static func loadPics() -> [Picture] {
        guard let stringified = UserDefaults.standard.string(forKey: PicsKey) else { return [] }
        guard let asJson = Json.asJson(stringified) else { return [] }
        do {
            return try PicsLibrary.parsePics(obj: asJson).map({ (p) in Picture(meta: p) })
        } catch {
            return []
        }
    }
    
    static func loadBlocked() -> [String] {
        return UserDefaults.standard.stringArray(forKey: BlockedImageKeys) ?? []
    }
}
