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
}

class PreviewPicsVM: PicsVMLike {
    @Published var pics: [PicMeta] = []
    
    func load() {
        
    }
}
