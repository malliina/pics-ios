//
//  PicsVM.swift
//  pics-ios
//
//  Created by Michael Skogberg on 18.5.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

protocol PicsVMLike: ObservableObject {
    var pics: [PicMeta] { get }
    
//    func load()
    func loadPics(for user: Username?)
    func remove(key: ClientKey)
    func block(key: ClientKey)
    func resetData()
}

class PicsVM: PicsVMLike {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    
    @Published var pics: [PicMeta] = []
    
    private var library: PicsLibrary { Backend.shared.library }
    private var authCancellation: AWSCancellationTokenSource? = nil
    
    func loadPics(for user: Username?) {
        if let user = user {
            loadPrivatePics(for: user)
        } else {
            loadAnonymousPics()
        }
    }
    
    private func loadPrivatePics(for user: Username) {
//        mightHaveMore = true
        authCancellation = AWSCancellationTokenSource()
        let _ = Tokens.shared.retrieveUserInfo(cancellationToken: authCancellation).subscribe { event in
            switch event {
            case .success(let userInfo):
                self.load(with: userInfo.token)
//                self.library.syncOffline(for: userInfo.username)
            case .failure(let error):
                self.onLoadError(error: error)
            }
        }
    }
    
    private func loadAnonymousPics() {
//        mightHaveMore = true
        load(with: nil)
    }
    
    private func onLoadError(error: Error) {
        log.error("Load error \(error)")
    }
    
    func load(with token: AWSCognitoIdentityUserSessionToken?) {
        Task {
            do {
                Backend.shared.updateToken(new: token)
                try await appendPics()
            } catch let err {
                log.error("Failed to load. \(err)")
            }
        }
    }
    
    func appendPics(limit: Int = PicsVC.itemsPerLoad) async throws {
        let beforeCount = pics.count
        let batch = try await library.loadAsync(from: beforeCount, limit: limit)
        log.info("Got batch of \(batch.count) pics")
        DispatchQueue.main.async {
            self.pics += batch
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
        DispatchQueue.main.async {
            self.pics = []
        }
        Tokens.shared.clearDelegates()
//        socket.disconnect()
//        isOnline = false
//        resetDisplay()
    }
}

class PreviewPicsVM: PicsVMLike {
    @Published var pics: [PicMeta] = []
    
    func loadPics(for user: Username?) { }
    func resetData() { }
    func remove(key: ClientKey) { }
    func block(key: ClientKey) { }
}
