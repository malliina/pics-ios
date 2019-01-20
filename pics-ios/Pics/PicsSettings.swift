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
    static let Uploads = "pic_uploads"
    let EulaAccepted = "eula_accepted"
    private static let BlockedImageKeys = "blocked_keys"
    
    let prefs = UserDefaults.standard
    
    private var cachedPictures: [Picture] = PicsSettings.loadPics()
    private var blockedKeys: [ClientKey] = PicsSettings.loadBlocked()
    
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
    
    var blockedImageKeys: [ClientKey] {
        get { return blockedKeys }
        set (newValue) {
            blockedKeys = newValue
            prefs.set(newValue.map { $0.key }, forKey: PicsSettings.BlockedImageKeys)
        }
    }
    
    // Upload tasks whose files must be deleted on completion
    var uploads: [UploadTask] {
        get { return loadUploads() }
        set (newValue) { saveUploads(tasks: newValue) }
    }
    
    func saveUpload(task: UploadTask) {
        var ups = uploads
        ups.removeAll { (t) -> Bool in
            t.id == task.id
        }
        ups.append(task)
        uploads = ups
    }
    
    func removeUpload(id: Int) -> UploadTask? {
        var ups = uploads
        if let index = uploads.indexOf({ $0.id == id }), let task = uploads.find({ $0.id == id }) {
            ups.remove(at: index)
            uploads = ups
            return task
        } else {
            return nil
        }
    }
    
    func block(key: ClientKey) {
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
    
    private func saveUploads(tasks: [UploadTask]) {
        let jsons = tasks.map { UploadTask.write(task: $0) } as AnyObject
        let json = [ UploadTask.Tasks: jsons ]
        prefs.set(Json.stringifyObject(json), forKey: PicsSettings.Uploads)
    }
    
    private func loadUploads() -> [UploadTask] {
        guard let stringified = prefs.string(forKey: PicsSettings.Uploads) else { return [] }
        guard let json = Json.asJson(stringified) else { return [] }
        do {
            return try UploadTask.parseList(obj: json)
        } catch {
            return []
        }
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
    
    static func loadBlocked() -> [ClientKey] {
        return (UserDefaults.standard.stringArray(forKey: BlockedImageKeys) ?? []).map { s in ClientKey(key: s) }
    }
}
