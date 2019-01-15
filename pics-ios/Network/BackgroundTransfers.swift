//
//  BackgroundTransfers.swift
//  pics-ios
//
//  Created by Michael Skogberg on 08/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

typealias SessionID = String
public typealias RelativePath = String
public typealias DestinationURL = URL

class BackgroundTransfers: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, URLSessionDelegate {
    let log = LoggerFactory.shared.network(BackgroundTransfers.self)
    typealias TaskID = Int
    
    static let uploader = BackgroundTransfers(basePath: "pics-transfers", sessionID: "com.malliina.pics.pics", oldTasks: [:])
    
    // let events = Event<DownloadProgressUpdate>()
    
    private let fileManager = FileManager.default
    let basePath: String
    
    private let sessionID: SessionID
    private var downloads: [TaskID: TransferInfo] = [:]
    // Upload tasks whose files must be deleted on completion
    private var uploads: [UploadTask] = PicsSettings.shared.uploads
    let lockQueue: DispatchQueue
    
    lazy var session: Foundation.URLSession = self.setupSession()
    
    init(basePath: String, sessionID: SessionID, oldTasks: [TaskID: TransferInfo]) {
        self.basePath = basePath
        self.sessionID = sessionID
        self.downloads = oldTasks
        self.lockQueue = DispatchQueue(label: sessionID, attributes: [])
    }
    
    func setup() {
        let desc = session.sessionDescription ?? "session"
        log.info("Initialized \(desc)")
    }
    
    fileprivate func stringify(_ state: URLSessionTask.State) -> String {
        switch state {
        case .completed: return "Completed"
        case .running: return "Running"
        case .canceling: return "Canceling"
        case .suspended: return "Suspended"
        }
    }
    
    fileprivate func setupSession() -> Foundation.URLSession {
        let conf = URLSessionConfiguration.background(withIdentifier: sessionID)
        conf.sessionSendsLaunchEvents = true
        conf.isDiscretionary = false
        let session = URLSession(configuration: conf, delegate: self, delegateQueue: nil)
        session.getTasksWithCompletionHandler { (datas, uploads, downloads) -> Void in
            // removes outdated tasks
            let taskIDs = downloads.map({ (t) -> String in
                let stateDescribed = self.stringify(t.state)
                return "\(t.taskIdentifier): \(stateDescribed)"
            })
            self.synchronized {
                let actualTasks = self.downloads.filterKeys({ (taskID, value) -> Bool in
                    downloads.exists({ (task) -> Bool in
                        return task.taskIdentifier == taskID
                    })
                })
                if !taskIDs.isEmpty {
                    self.log.info("Restoring \(actualTasks.count) tasks, system had tasks \(taskIDs)")
                }
                self.downloads = actualTasks
            }
        }
        return session
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        if let downloadInfo = downloads[taskID] {
            let destURL = downloadInfo.destinationURL
            // Attempts to remove any previous file
            do {
                try fileManager.removeItem(at: destURL)
                log.info("Removed previous version of \(destURL).")
            } catch {
            }
            let relPath = downloadInfo.relativePath
            do {
                try fileManager.moveItem(at: location, to: destURL)
                log.info("Completed download of \(relPath).")
            } catch let err {
                log.error("File copy of \(relPath) failed to \(destURL). \(err)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        log.info("Resumed at \(fileOffset)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        let taskOpt = downloads[taskID]
        if let info = taskOpt,
            let writtenDelta = StorageSize.fromBytes(bytesWritten),
            let written = StorageSize.fromBytes(totalBytesWritten) {
            let expectedSize = StorageSize.fromBytes(totalBytesExpectedToWrite)
            let _ = DownloadProgressUpdate(info: info, writtenDelta: writtenDelta, written: written, totalExpected: expectedSize)
        } else {
            if taskOpt == nil {
                //info("Download task not found: \(taskID)")
            } else {
                log.info("Unable to parse bytes of download progress: \(bytesWritten), \(totalBytesWritten)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskID = task.taskIdentifier
        if let error = error {
            let desc = error.localizedDescription
            log.info("Download error for \(taskID): \(desc)")
        } else {
            log.info("Task \(taskID) complete.")
        }
        
        removeTask(taskID)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Check the docs if unsure about what's going on here
        let sid = session.configuration.identifier
        log.info("All complete for session \(sid ?? "unknown")")
        DispatchQueue.main.async {
            if let sid = sid, let app = UIApplication.shared.delegate as? AppDelegate,
                let handler = app.transferCompletionHandlers.removeValue(forKey: sid) {
                handler()
            }
        }
    }
    
    func synchronized(_ f: @escaping () -> Void) {
        self.lockQueue.async {
            f()
        }
    }
    
    private func download(_ src: URL, info: TransferInfo) {
        let request = URLRequest(url: src)
        let task = session.downloadTask(with: request)
        saveTask(task.taskIdentifier, di: info)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: {
            task.resume()
        })
    }
    
    func upload(_ dest: URL, headers: [String: String], file: URL, deleteOnComplete: Bool) {
        var req = URLRequest(url: dest)
        req.addCsrf()
        req.httpMethod = HttpClient.POST
        for (key, value) in headers {
            req.addValue(value, forHTTPHeaderField: key)
        }
        let task = session.uploadTask(with: req, fromFile: file)
        if deleteOnComplete {
            saveUpload(task: UploadTask(id: task.taskIdentifier, folder: file.deletingLastPathComponent().lastPathComponent, filename: file.lastPathComponent))
        }
        task.resume()
    }
    
    func saveTask(_ taskID: Int, di: TransferInfo) {
        synchronized {
            self.downloads[taskID] = di
        }
    }
    
    func saveUpload(task: UploadTask) {
        synchronized {
            self.uploads.append(task)
            PicsSettings.shared.uploads = self.uploads
        }
    }
    
    func removeTask(_ taskID: Int) {
        synchronized {
            if let task = self.downloads.removeValue(forKey: taskID) {
                if task.deleteOnComplete {
                    self.removeUploaded(id: taskID)
                }
            }
        }
    }
    
    private func removeUploaded(id: Int) {
        if let index = uploads.indexOf({ $0.id == id }), let task = uploads.find({ $0.id == id }) {
            uploads.remove(at: index)
            let file = LocalPics.shared.computeUrl(folder: task.folder, filename: task.filename)
            do {
                try fileManager.removeItem(at: file)
                log.info("Removed \(file) of task \(id).")
            } catch {
                log.error("Failed to remove \(file) of task \(id).")
            }
            PicsSettings.shared.uploads = uploads
        }
    }
    
    func prepareDestination(_ relativePath: RelativePath) -> String? {
        let destPath = pathTo(relativePath)
        let dir = destPath.stringByDeletingLastPathComponent()
        let dirSuccess: Bool
        do {
            try self.fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            dirSuccess = true
        } catch _ {
            dirSuccess = false
        }
        return dirSuccess ? destPath : nil
    }
    
    func pathTo(_ relativePath: RelativePath) -> String {
        return self.basePath + "/" + relativePath.replacingOccurrences(of: "\\", with: "/")
    }
    
    func urlTo(_ relativePath: RelativePath) -> URL? {
        return URL(fileURLWithPath: pathTo(relativePath))
    }
    
}
