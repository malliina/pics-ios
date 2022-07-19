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

protocol PicsVMLike: ObservableObject {
    var pics: [PicMeta] { get }
    var hasMore: Bool { get }
    var isPrivate: Bool { get }
    
//    func loadPics(for user: Username?)
    func loadMore()
    func loadPicsAsync(for user: Username?) async
    func remove(key: ClientKey)
    func block(key: ClientKey)
    func resetData()
    func onPublic()
    func onPrivate(user: Username)
    func signOut()
}

extension PicsVMLike {
    func loadPics(for user: Username?) {
        Task {
            await loadPicsAsync(for: user)
        }
    }
}

class PicsVM: PicsVMLike {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    let navController: UINavigationController
    
    init(navController: UINavigationController) {
        self.navController = navController
    }
    
    let user = User.shared
    
    @Published var pics: [PicMeta] = []
    @Published private(set) var isPrivate = User.shared.isPrivate
    @Published private(set) var hasMore = false
    
//    var barStyle: UIBarStyle { isPrivate ? .black : .default }
    var titleTextColor: UIColor { isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    private var library: PicsLibrary { Backend.shared.library }
    private var picsSettings: PicsSettings { PicsSettings.shared }
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    private var authCancellation: AWSCancellationTokenSource? = nil
    
    func loadMore() {
        loadPics(for: user.activeUser)
        // log.info("load more now")
    }
    
    func loadPicsAsync(for user: Username?) async {
        Task {
            do {
                if let user = user {
                    try await loadPrivatePics(for: user)
                } else {
                    try await loadAnonymousPics()
                }
            } catch let error {
                onLoadError(error: error)
            }
        }
    }
    
    private func loadPrivatePics(for user: Username) async throws {
//        mightHaveMore = true
        authCancellation = AWSCancellationTokenSource()
        let userInfo = try await Tokens.shared.retrieveUserInfoAsync(cancellationToken: authCancellation)
        try await load(with: userInfo.token)
//        self.library.syncOffline(for: userInfo.username)
    }
    
    private func loadAnonymousPics() async throws {
//        mightHaveMore = true
        try await load(with: nil)
    }
    
    private func onLoadError(error: Error) {
        log.error("Load error \(error)")
    }
    
    func load(with token: AWSCognitoIdentityUserSessionToken?) async throws {
        Backend.shared.updateToken(new: token)
        try await appendPics()
    }
    
    func appendPics(limit: Int = PicsVC.itemsPerLoad) async throws {
        let beforeCount = pics.count
        let batch = try await library.loadAsync(from: beforeCount, limit: limit)
        log.info("Got batch of \(batch.count) pics from \(beforeCount)")
        onUiThread {
            self.pics += batch
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
    
    private func removeLocally(key: ClientKey) {
        DispatchQueue.main.async {
            self.pics = self.pics.filter { pic in pic.key != key }
        }
    }
    
    func resetData() {
        onUiThread {
            self.pics = []
            Tokens.shared.clearDelegates()
            Task {
                await self.loadPicsAsync(for: nil)
            }
        }
//        socket.disconnect()
//        isOnline = false
//        resetDisplay()
    }
    
    func onPublic() {
        picsSettings.activeUser = nil
        onUiThread {
            self.pics = []
            self.isPrivate = false
            
            Task {
                await self.updateStyle()
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
            self.pics = []
            self.isPrivate = true
            Task {
                await self.updateStyle()
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
    
    @MainActor
    func updateStyle() {
//        navController.navigationBar.barStyle = barStyle
        navController.navigationBar.titleTextAttributes = [.foregroundColor: self.titleTextColor]
    }
    
    func signOut() {
        log.info("Signing out...")
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        picsSettings.activeUser = nil
//        self.collectionView?.backgroundView = nil
//        self.navigationController?.navigationBar.isHidden = true
        resetData()
    }
    
    func onUiThread(_ f: @escaping () -> Void) {
        DispatchQueue.main.async(execute: f)
    }
}

class PreviewPicsVM: PicsVMLike {
    @Published var pics: [PicMeta] = []
    @Published var hasMore: Bool = false
    @Published var isPrivate: Bool = false
    func loadMore() { }
    func loadPicsAsync(for user: Username?) async { }
    func resetData() { }
    func onPublic() { }
    func onPrivate(user: Username) { }
    func signOut() { }
    func remove(key: ClientKey) { }
    func block(key: ClientKey) { }
}