//
//  Downloader.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

class Downloader {
    static let shared = Downloader()
    private let log = LoggerFactory.shared.network("Downloader")
    fileprivate var tasks = [URLSessionTask]()
    
    // https://andreygordeev.com/2017/02/20/uitableview-prefetching/
    func download(url: URL, onData: @escaping (Data) -> Void) {
        guard tasks.index(where: { $0.originalRequest?.url == url }) == nil else {
            // We're already downloading the image.
            return
        }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            // Perform UI changes only on main thread.
            DispatchQueue.main.async {
                if let data = data {
                    onData(data)
//                    self.items[index].image = image
//                    // Reload cell with fade animation.
//                    let indexPath = IndexPath(row: index, section: 0)
//                    if self.tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
//                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
//                    }
                } else {
                    self.log.warn("No data returned in download of \(url.absoluteString)")
                }
            }
        }
        task.resume()
        tasks.append(task)
    }
    
    func cancelDownload(forUrl url: URL) {
        guard let taskIndex = tasks.index(where: { $0.originalRequest?.url == url }) else {
            return
        }
        let task = tasks[taskIndex]
        task.cancel()
        tasks.remove(at: taskIndex)
    }
}
