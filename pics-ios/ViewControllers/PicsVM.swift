//
//  PicsVM.swift
//  pics-ios
//
//  Created by Michael Skogberg on 18.5.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

class User {
    static let shared = User()
    
    var picsSettings: PicsSettings { PicsSettings.shared }
    var activeUser: Username? { picsSettings.activeUser }
    var isPrivate: Bool { picsSettings.activeUser != nil 		}
    var currentUsernameOrAnon: Username { activeUser ?? Username.anon }
}

protocol PicsVMLike: ObservableObject, AuthInit {
    var isOnline: Bool { get }
    var pics: [Picture] { get }
    var hasMore: Bool { get }
    var isPrivate: Bool { get }
    var showLogin: Bool { get set }
    var showNewPass: Bool { get set }
    var loginHandler: LoginHandler { get }
    func loadMore() async
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async
    func display(newPics: [Picture])
    func remove(key: ClientKey)
    func block(key: ClientKey)
    func resetData()
    func onPublic()
    func onPrivate(user: Username)
    func signOut()
    
    func connect()
    func disconnect()
}

protocol AuthInit {
    func reInit() async
    func changeStyle(dark: Bool)
}

extension PicsVM: AuthInit {
    func reInit() async {
        authCancellation?.cancel()
        authCancellation?.dispose()
        await loadPicsAsync(for: user.activeUser, initialOnly: false)
    }
    
    func changeStyle(dark: Bool) {
        
    }
}

extension PicsVM: PicsDelegate {
    func onPics(pics: [PicMeta]) {
        let (existingPics, newPics) = pics.partition(contains)
        existingPics.forEach { meta in
            updateMeta(pic: meta)
        }
        let picsToAdd = newPics.filter { pic in
            !isBlocked(pic: pic)
        }.map { meta in
            Picture(meta: meta)
        }
        let updated = picsToAdd.reversed() + self.pics
        savePics(newPics: updated)
    }
    
    func onPicsRemoved(keys: [ClientKey]) {
        removeLocally(keys: keys)
    }
    
    func onProfile(info: ProfileInfo) {
        
    }
    
    private func updateMeta(pic: PicMeta) {
        log.info("Metadata update not supported currently (\(pic.key).")
//        if let clientKey = pic.clientKey, let idx = indexFor(clientKey) {
//          self.pics[idx] = self.pics[idx].withMeta(meta: pic)
//        } else {
//            log.info("Cannot update \(pic.key), pic not found in memory.")
//        }
    }
    
    private func indexFor(_ clientKey: ClientKey) -> Int? {
        self.pics.firstIndex(where: { (p) -> Bool in
            p.meta.clientKey == clientKey
        })
    }
    
    private func contains(pic: PicMeta) -> Bool {
        self.pics.contains(where: { p -> Bool in (pic.clientKey != nil && p.meta.clientKey == pic.clientKey) || p.meta.key == pic.key })
    }
}

class PicsVM: PicsVMLike {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    
    static let itemsPerLoad = 100
    static let preferredItemSize: Double = Devices.isIpad ? 200 : 130
    
    let user = User.shared
    
    @Published private(set) var isOnline = false
    var currentUsernameOrAnon: Username { User.shared.activeUser ?? Username.anon }
    
    @Published var pics: [Picture] = []
    private(set) var isPrivate = User.shared.isPrivate
    @Published private(set) var hasMore = false
    private var isInitial = true
    
    @Published var showLogin = false
    @Published var showNewPass = false
    
    private var library: PicsLibrary { Backend.shared.library }
    private var picsSettings: PicsSettings { PicsSettings.shared }
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    private var authCancellation: AWSCancellationTokenSource? = nil

    var cognito: CognitoDelegate? = nil
    var loginHandler: LoginHandler { cognito!.handler }
    
    var socket: PicsSocket { Backend.shared.socket }
    
    let userChanged: (Username?) -> Void
    
    init(userChanged: @escaping (Username?) -> Void) {
        self.userChanged = userChanged
        socket.delegate = self
        let cognitoDelegate = CognitoDelegate(onShowLogin: {
            DispatchQueue.main.async {
                self.showLogin = true
            }
        }, onShowNewPass: {
            DispatchQueue.main.async {
                self.showNewPass = true
            }
        })
        cognito = cognitoDelegate
        Tokens.shared.pool.delegate = cognitoDelegate
    }
    
    func connect() {
        socket.reconnect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    private func savePics(newPics: [Picture]) {
        isOnline = true
        self.pics = newPics
        let _ = self.picsSettings.save(pics: newPics, for: self.currentUsernameOrAnon)
    }
    
    func loadMore() async {
        log.info("Loading more for \(self.currentUsernameOrAnon)...")
        await loadPicsAsync(for: user.activeUser, initialOnly: false)
    }
    
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async {
        if !initialOnly || isInitial {
            isInitial = false
            if initialOnly {
                onUiThread {
                    self.pics = []
                    self.log.info("Offline count \(self.pics.count)")
                }
            }
            do {
                if let user = user {
                    try await loadPrivatePics(for: user)
                } else {
                    try await loadAnonymousPics()
                }
                onUiThread {
                    if initialOnly {
                        self.userChanged(user)
                    }
                }
            } catch let error {
                onLoadError(error: error)
            }
        }
    }
    
    private func loadPrivatePics(for user: Username) async throws {
        log.info("Loading pics for \(user)...")
        authCancellation = AWSCancellationTokenSource()
        let userInfo = try await Tokens.shared.retrieveUserInfoAsync(cancellationToken: authCancellation)
        try await load(with: userInfo.token)
    }
    
    private func loadAnonymousPics() async throws {
        log.info("Loading anon pics...")
        try await load(with: nil)
    }
    
    private func onLoadError(error: Error) {
        log.error("Load error \(error)")
    }
    
    func load(with token: AWSCognitoIdentityUserSessionToken?) async throws {
        Backend.shared.updateToken(new: token)
        socket.reconnect()
        try await appendPics()
    }
    
    private func appendPics(limit: Int = PicsVM.itemsPerLoad) async throws {
        let beforeCount = pics.count
        let batch = try await library.loadAsync(from: beforeCount, limit: limit)
        log.info("Got batch of \(batch.count) pics from index \(beforeCount) with limit \(limit).")
        let syncedBatch: [PicMeta] = batch.map { meta in
            let key = meta.key
            guard let url = LocalPics.shared.findLocal(key: key) else {
//                log.debug("Local not found for '\(key)'.")
                return meta
            }
            log.info("Found local URL '\(url)' for '\(key)'.")
            return meta.withUrl(url: url)
        }
        onUiThread {
            self.savePics(newPics: self.pics + syncedBatch.map { p in Picture(meta: p) })
            self.hasMore = batch.count == limit
        }
    }
    
    private func isBlocked(pic: PicMeta) -> Bool {
        return PicsSettings.shared.blockedImageKeys.contains { $0 == pic.key }
    }
    
    func remove(key: ClientKey) {
        removeLocally(keys: [key])
        Task {
            do {
                let _ = try await library.deleteAsync(key: key)
            } catch let err {
                self.log.error("Failed to delete \(key). \(err)")
            }
        }
    }
    
    func block(key: ClientKey) {
        PicsSettings.shared.block(key: key)
        removeLocally(keys: [key])
    }
    
    func display(newPics: [Picture]) {
        let newPicsNewestFirst: [Picture] = newPics.reversed()
        let prepended = newPicsNewestFirst + self.pics
        DispatchQueue.main.async {
            self.savePics(newPics: prepended)
        }
    }
    
    private func removeLocally(keys: [ClientKey]) {
        DispatchQueue.main.async {
            self.savePics(newPics: self.pics.filter { pic in !keys.contains { key in
                pic.meta.key == key
            }})
        }
    }
    
    func resetData() {
        onUiThread {
            Tokens.shared.clearDelegates()
            self.isOnline = false
            self.savePics(newPics: [])
            self.isInitial = true
            self.isPrivate = false
            Task {
                await self.loadPicsAsync(for: nil, initialOnly: true)
            }
        }
    }
    
    func onPublic() {
        picsSettings.activeUser = nil
        onUiThread {
            self.isPrivate = false
            self.savePics(newPics: self.picsSettings.localPictures(for: Username.anon))
            self.hasMore = false
            self.userChanged(nil)
            
            Task {
                try await self.loadAnonymousPics()
            }
        }
        log.info("Current user is \(user.currentUsernameOrAnon)")
    }
    
    func onPrivate(user: Username) {
        picsSettings.activeUser = user
        onUiThread {
//            self.pics = []
            self.savePics(newPics: [])
            self.isPrivate = true
            self.hasMore = false
            self.userChanged(user)
            Task {
                try await self.loadPrivatePics(for: user)
            }
        }
    }
    
    func signOut() {
        log.info("Signing out...")
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        picsSettings.activeUser = nil
        resetData()
        adjustTitleTextColor(PicsColors.uiAlmostBlack)
        loginHandler.isComplete = false
    }
    
    private func adjustTitleTextColor(_ color: UIColor) {
        log.info("Adjusting title color")
    }
    
    func onUiThread(_ f: @escaping () -> Void) {
        DispatchQueue.main.async(execute: f)
    }
}

class PreviewPicsVM: PicsVMLike {
    func connect() {}
    func disconnect() {}
    var isOnline: Bool = false
    var pics: [Picture] = []
    var hasMore: Bool = false
    var isPrivate: Bool = false
    var showLogin: Bool = false
    var showNewPass: Bool = false
    var loginHandler: LoginHandler = LoginHandler()
    func loadMore() async { }
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async { }
    func resetData() { }
    func onPublic() { }
    func onPrivate(user: Username) { }
    func signOut() { }
    func remove(key: ClientKey) { }
    func block(key: ClientKey) { }
    func display(newPics: [Picture]) { }
    func reInit() { }
    func changeStyle(dark: Bool) { }
}
