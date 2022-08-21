//
//  Downloader.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

enum DownloadResult {
    case data(data: Data)
    case failure(error: Error)
}

class Downloader {
    static let shared = Downloader()
    private let log = LoggerFactory.shared.network(Downloader.self)
    fileprivate var tasks = [URLSessionTask]()
    private let queue = DispatchQueue(label: "DownloaderTaskQueue")
    
    // Adapted from https://andreygordeev.com/2017/02/20/uitableview-prefetching/
    func download(url: URL, onData: @escaping (DownloadResult) -> Void) {
        self.queue.sync {
//            guard tasks.firstIndex(where: { $0.originalRequest?.url == url }) == nil else {
//                // We're already downloading the URL
//                log.warn("Already downloading \(url.absoluteString), aborting")
//                return
//            }
            log.info("Submitting download of \(url)")
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                self.queue.sync {
                    let log = self.log
//                    log.info("Task \(url) complete.")
                    if let idx = self.tasks.firstIndex(where: { $0.originalRequest?.url == url }) {
                        self.tasks.remove(at: idx)
                    }
                    if let error = error {
                        if error.localizedDescription == "cancelled" {
                            log.info("Cancelled \(url)")
                        } else {
                            log.error("Download failed with error \(error)")
                        }
                        onData(.failure(error: error))
                    } else {
                        if let data = data {
        //                    log.info("Downloaded \(url.absoluteString)")
                            onData(.data(data: data))
                        } else {
                            log.warn("No data returned in download of \(url.absoluteString), but also no error reported")
                            onData(.failure(error: AppError.simple("No data returned")))
                        }
                    }
                }
            }
            task.resume()
            tasks.append(task)
        }
    }
    
    func downloadAsync(url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            download(url: url) { data in
                switch data {
                case .data(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func cancelDownload(forUrl url: URL) {
        queue.sync {
            guard let taskIndex = tasks.firstIndex(where: { $0.originalRequest?.url == url }) else {
                return
            }
            let task = tasks[taskIndex]
            task.cancel()
            tasks.remove(at: taskIndex)
        }
    }
}
