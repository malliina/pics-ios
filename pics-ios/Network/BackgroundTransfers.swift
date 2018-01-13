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

class TransferResult {
    let url: URL
    let data: Data?
    let response: URLResponse?
    let error: Error?
    
    var isError: Bool { return error != nil }
    var httpResponse: HttpResponse? {
        get {
            if let r = response as? HTTPURLResponse, let d = data {
                return HttpResponse(http: r, data: d)
            } else {
                return nil
            }
        }
    }
    
    init(url: URL, data: Data?, response: URLResponse?, error: Error?) {
        self.url = url
        self.data = data
        self.response = response
        self.error = error
    }
}
class DownloadProgressUpdate {
    let info: DownloadInfo
    let writtenDelta: StorageSize
    let written: StorageSize
    let totalExpected: StorageSize?
    
    var relativePath: String { return info.relativePath }
    var destinationURL: URL { return info.destinationURL }
    
    var isComplete: Bool? { get { return written == totalExpected } }
    
    init(info: DownloadInfo, writtenDelta: StorageSize, written: StorageSize, totalExpected: StorageSize?) {
        self.info = info
        self.writtenDelta = writtenDelta
        self.written = written
        self.totalExpected = totalExpected
    }
    
    func copy(_ newTotalExpected: StorageSize) -> DownloadProgressUpdate {
        return DownloadProgressUpdate(info: info, writtenDelta: writtenDelta, written: written, totalExpected: newTotalExpected)
    }
    
    static func initial(info: DownloadInfo, size: StorageSize) -> DownloadProgressUpdate {
        return DownloadProgressUpdate(info: info, writtenDelta: StorageSize.Zero, written: StorageSize.Zero, totalExpected: size)
    }
}

open class DownloadInfo {
    open let relativePath: RelativePath
    open let destinationURL: DestinationURL
    
    public init(relativePath: RelativePath, destinationURL: DestinationURL) {
        self.relativePath = relativePath
        self.destinationURL = destinationURL
    }
}

class BackgroundTransfers: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, URLSessionDelegate {
    let log = LoggerFactory.shared.network(BackgroundTransfers.self)
    typealias TaskID = Int
    
    static let picsUploader = BackgroundTransfers(basePath: "todo-pics-path", sessionID: "com.malliina.pics.pics", oldTasks: [:])
    
    // let events = Event<DownloadProgressUpdate>()
    
    fileprivate let fileManager = FileManager.default
    let basePath: String
    
    fileprivate let sessionID: SessionID
    fileprivate var tasks: [TaskID: DownloadInfo] = [:]
    let lockQueue: DispatchQueue
    
    lazy var session: Foundation.URLSession = self.setupSession()
    
    init(basePath: String, sessionID: SessionID, oldTasks: [TaskID:DownloadInfo]) {
        self.basePath = basePath
        self.sessionID = sessionID
        self.tasks = oldTasks // PimpSettings.sharedInstance.tasks(sessionID)
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
        let session = Foundation.URLSession(configuration: conf, delegate: self, delegateQueue: nil)
        session.getTasksWithCompletionHandler { (datas, uploads, downloads) -> Void in
            // removes outdated tasks
            let taskIDs = downloads.map({ (t) -> String in
                let stateDescribed = self.stringify(t.state)
                return "\(t.taskIdentifier): \(stateDescribed)"
            })
            self.synchronized {
                let actualTasks = self.tasks.filterKeys({ (taskID, value) -> Bool in
                    downloads.exists({ (task) -> Bool in
                        return task.taskIdentifier == taskID
                    })
                })
                if !taskIDs.isEmpty {
                    self.log.info("Restoring \(actualTasks.count) tasks, system had tasks \(taskIDs)")
                }
                self.tasks = actualTasks
            }
        }
        return session
    }
    
    func synchronized(_ f: @escaping () -> Void) {
        self.lockQueue.async {
            f()
        }
    }
    
    func download(_ url: URL, relativePath: RelativePath) -> DownloadInfo? {
        log.info("Preparing download of \(relativePath) from \(url)")
        if let destPath = prepareDestination(relativePath) {
            let destURL = URL(fileURLWithPath: destPath)
            let info = DownloadInfo(relativePath: relativePath, destinationURL: destURL)
            self.log.info("Download \(url) to dest path \(destPath) with url \(destURL)")
            download(url, info: info)
            return info
        } else {
            log.error("Unable to prepare destination URL \(relativePath)")
            return nil
        }
    }
    
    private func download(_ src: URL, info: DownloadInfo) {
        let request = URLRequest(url: src)
        let task = session.downloadTask(with: request)
        saveTask(task.taskIdentifier, di: info)
        // Delays the (background) download so that any playback might start earlier
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: {
            task.resume()
        })
    }
    
    func upload(_ dest: URL, headers: [String: String], file: URL, onComplete: @escaping (TransferResult) -> Void) {
        var req = URLRequest(url: dest)
        req.httpMethod = HttpClient.POST
        for (key, value) in headers {
            req.addValue(value, forHTTPHeaderField: key)
        }
        let task = session.uploadTask(with: req, fromFile: file)
        saveTask(task.taskIdentifier, di: DownloadInfo(relativePath: file.lastPathComponent, destinationURL: dest))
        task.resume()
    }
    
    func saveTask(_ taskID: Int, di: DownloadInfo) {
        synchronized {
            self.tasks[taskID] = di
            self.persistTasks()
        }
    }
    
    func removeTask(_ taskID: Int) {
        synchronized {
            self.tasks.removeValue(forKey: taskID)
            self.persistTasks()
        }
    }
    
    func persistTasks() {
        //        info("Saving \(tasks)")
        //        PimpSettings.sharedInstance.saveTasks(self.sessionID, tasks: self.tasks)
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
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        if let downloadInfo = tasks[taskID] {
            let destURL = downloadInfo.destinationURL
            // Attempt to remove any previous file
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
                log.error("Copy failed \(err)")
                log.info("File copy of \(relPath) failed to \(destURL).")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        log.info("Resumed at \(fileOffset)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        let taskOpt = tasks[taskID]
        if let info = taskOpt,
            let writtenDelta = StorageSize.fromBytes(bytesWritten),
            let written = StorageSize.fromBytes(totalBytesWritten) {
            let expectedSize = StorageSize.fromBytes(totalBytesExpectedToWrite)
            let _ = DownloadProgressUpdate(info: info, writtenDelta: writtenDelta, written: written, totalExpected: expectedSize)
            // log.info("")
            // events.raise(update)
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
        let sid = session.configuration.identifier
        log.info("All complete for session \(sid ?? "unknown")")
        DispatchQueue.main.async {
            if let sid = sid, let app = UIApplication.shared.delegate as? AppDelegate,
                let handler = app.transferCompletionHandlers.removeValue(forKey: sid) {
                handler()
            }
        }
    }
}
