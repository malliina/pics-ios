//
//  PicsSettings.swift
//  pics-ios
//
//  Created by Michael Skogberg on 27/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation

// Hack because Encodable can't encode a String
struct Wrapped<T: Codable>: Codable {
    let value: T
}

class PicsPrefs {
    static let shared = PicsPrefs()
    
    let prefs = UserDefaults.standard
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    func save<T: Encodable>(_ contents: T, key: String) -> ErrorMessage? {
        do {
            let encoded = try encoder.encode(contents)
            guard let asString = String(data: encoded, encoding: .utf8) else {
                return ErrorMessage("Unable to encode data for key '\(key)' to String.")
            }
            prefs.set(asString, forKey: key)
            return nil
        } catch let err {
            return ErrorMessage("Unable to encode to key '\(key)'. \(err)")
        }
    }
    
    func load<T: Decodable>(_ key: String, _ t: T.Type) -> T? {
        guard let asString = prefs.string(forKey: key), let data = asString.data(using: .utf8) else { return nil }
        return try? decoder.decode(t, from: data)
    }
    
    func bool(forKey key: String) -> Bool {
        return load(key, Wrapped<Bool>.self)?.value ?? false
    }
    
    func string(forKey key: String) -> String? {
        return load(key, Wrapped<String>.self)?.value
    }
    
    func saveString(_ contents: String, key: String) -> ErrorMessage? {
        return save(Wrapped<String>(value: contents), key: key)
    }
    
    func saveBool(_ contents: Bool, key: String) -> ErrorMessage? {
        return save(Wrapped<Bool>(value: contents), key: key)
    }
}

class PicsSettings {
    let log = LoggerFactory.shared.system(PicsSettings.self)
    
    static let shared = PicsSettings()
    
    let IsPublic = "v2-is_private"
    let PicsKey = "pics"
    let Uploads = "pic_uploads"
    let EulaAccepted = "v2-eula_accepted"
    private static let BlockedImageKeys = "v2-blocked_keys"
    
    let prefs = PicsPrefs.shared
    
    private var blockedKeys: [ClientKey] = PicsSettings.loadBlocked()
    
    init() {
    }
    
    func key(for user: Username) -> String { return "v2-pics-\(user.encoded())" }
    
    var isPrivate: Bool {
        get { return prefs.bool(forKey: IsPublic) }
        set (newValue) {
            let _ = prefs.saveBool(newValue, key: IsPublic)
        }
    }
    
    var isEulaAccepted: Bool {
        get { return prefs.bool(forKey: EulaAccepted) }
        set (newValue) { let _ = prefs.saveBool(newValue, key: EulaAccepted) }
    }
    
    var blockedImageKeys: [ClientKey] {
        get { return blockedKeys }
        set (newValue) {
            blockedKeys = newValue
            let _ = prefs.save(newValue, key: PicsSettings.BlockedImageKeys)
        }
    }
    
    // Upload tasks whose files must be deleted on completion
    var uploads: [UploadTask] {
        get { return prefs.load(Uploads, UploadTasks.self)?.tasks ?? [] }
        set (newValue) { let _ = prefs.save(UploadTasks(tasks: newValue), key: Uploads) }
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
    
    func save(pics: [Picture], for user: Username?) -> ErrorMessage? {
        let refs = pics.map { pic in PicRef(filename: pic.meta.url.lastPathComponent, added: pic.meta.added) }
        return prefs.save(PicRefs(pics: refs), key: key(for: user ?? Username.anon))
    }
    
    func localPictures(for user: Username?) -> [Picture] {
        let metas = prefs.load(key(for: user ?? Username.anon), PicRefs.self)?.pics ?? []
        return metas.compactMap { PicMeta.ref($0).map { meta in Picture(meta: meta) } }
    }
    
    static func loadBlocked() -> [ClientKey] {
        return (UserDefaults.standard.stringArray(forKey: BlockedImageKeys) ?? []).map { s in ClientKey(s) }
    }
}
