//
//  PicsVM.swift
//  pics-ios
//
//  Created by Michael Skogberg on 18.5.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation

protocol PicsVMLike: ObservableObject {
    var pics: [PicMeta] { get }
    
    func load()
    func remove(key: ClientKey)
    func block(key: ClientKey)
}

class PicsVM: PicsVMLike {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    
    @Published var pics: [PicMeta] = []
    
    private var library: PicsLibrary { Backend.shared.library }
    
    func load() {
        Task {
            do {
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
}

class PreviewPicsVM: PicsVMLike {
    @Published var pics: [PicMeta] = []
    
    func load() { }
    
    func remove(key: ClientKey) { }
    
    func block(key: ClientKey) { }
}
