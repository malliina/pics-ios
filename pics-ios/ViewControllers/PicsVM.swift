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
    var pics: [Picture] { get }
    var hasMore: Bool { get }
    var isPrivate: Bool { get }
    
    func loadMore() async
    func loadPicsAsync(for user: Username?, initialOnly: Bool) async
    func display(newPics: [Picture])
    func remove(key: ClientKey)
    func block(key: ClientKey)
    func resetData()
    func onPublic()
    func onPrivate(user: Username)
    func signOut()
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

class PicsVM: PicsVMLike {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    
    let user = User.shared
    
//    @Published var offlinePics: [Picture] = []
//    @Published var onlinePics: [Picture] = []
    @Published private(set) var isOnline = false
    var currentUsernameOrAnon: Username { User.shared.activeUser ?? Username.anon }
    
    @Published var pics: [Picture] = []
    
//    var pics2: [Picture] {
//        get {
//            isOnline ? onlinePics : offlinePics
//        }
////        set (newPics) {
////            let _ = picsSettings.save(pics: newPics, for: currentUsernameOrAnon)
////            if isOnline {
////                if let f = newPics.first {
////                    log.info("First is \(f.meta.key)")
////                }
////                onlinePics = newPics
////            } else {
////                offlinePics = newPics
////            }
////        }
//    }
    private(set) var isPrivate = User.shared.isPrivate
    @Published private(set) var hasMore = false
    private var isInitial = true
    var titleTextColor: UIColor { isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    private var library: PicsLibrary { Backend.shared.library }
    private var picsSettings: PicsSettings { PicsSettings.shared }
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    private var authCancellation: AWSCancellationTokenSource? = nil
    
    let userChanged: (Username?) -> Void
    
    init(userChanged: @escaping (Username?) -> Void) {
        self.userChanged = userChanged
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
                self.pics.removeAll()
                self.pics = picsSettings.localPictures(for: currentUsernameOrAnon)
                log.info("Offline count \(pics.count)")
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
//        self.library.syncOffline(for: userInfo.username)
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
        try await appendPics()
    }
    
    private func appendPics(limit: Int = PicsVC.itemsPerLoad) async throws {
        let beforeCount = pics.count
        let batch = try await library.loadAsync(from: beforeCount, limit: limit)
//        log.info("Got batch of \(batch.count) pics from \(beforeCount) online \(isOnline) private \(isPrivate) first is \(batch.first?.key.key ?? "none")")
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
        removeLocally(key: key)
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
        removeLocally(key: key)
    }
    
    func display(newPics: [Picture]) {
        let newPicsNewestFirst: [Picture] = newPics.reversed()
        let prepended = newPicsNewestFirst + self.pics
        DispatchQueue.main.async {
            self.savePics(newPics: prepended)
        }
    }
    
    private func removeLocally(key: ClientKey) {
        DispatchQueue.main.async {
//            self.offlinePics = self.offlinePics.filter { pic in pic.meta.key != key }
            self.savePics(newPics: self.pics.filter { pic in pic.meta.key != key })
        }
    }
    
    func resetData() {
        onUiThread {
            Tokens.shared.clearDelegates()
            self.isOnline = false
            self.savePics(newPics: [])
//            self.offlinePics = []
            Task {
                await self.loadPicsAsync(for: nil, initialOnly: true)
            }
        }
//        socket.disconnect()
//        isOnline = false
//        resetDisplay()
    }
    
    func onPublic() {
        picsSettings.activeUser = nil
        onUiThread {
            self.isPrivate = false
//            self.pics = self.picsSettings.localPictures(for: Username.anon)
            self.savePics(newPics: self.picsSettings.localPictures(for: Username.anon))
            self.hasMore = false
            self.userChanged(nil)
            
            Task {
                try await self.loadAnonymousPics()
            }
        }
//        onUiThread {
//            self.offlinePics = self.picsSettings.localPictures(for: Username.anon)
//            self.collectionView?.reloadData()
//        }
        
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
//            DispatchQueue.main.async {
//            self.offlinePics = self.picsSettings.localPictures(for: user)
//                self.updateStyle()
//                isPrivate = true
//            self.collectionView?.reloadData()
//            }
    }
    
    func signOut() {
        log.info("Signing out...")
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        picsSettings.activeUser = nil
        resetData()
        adjustTitleTextColor(PicsColors.almostBlack)
    }
    
    private func adjustTitleTextColor(_ color: UIColor) {
        log.info("Adjusting title color")
    }
    
    func onUiThread(_ f: @escaping () -> Void) {
        DispatchQueue.main.async(execute: f)
    }
}

class PreviewPicsVM: PicsVMLike {
    @Published var pics: [Picture] = []
    @Published var hasMore: Bool = false
    @Published var isPrivate: Bool = false
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
