import Foundation
import UIKit

typealias SessionID = String
public typealias RelativePath = String
public typealias DestinationURL = URL

// The sequence of events when a background task is updated is:
//
// 1. This AppDelegate function is called:
// func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
//
// 2. This callback is called (perhaps multiple times, if multiple tasks are running):
// func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
//
// 3. Finally, this callback is called. The completionHandler provided in the AppDelegate (step 1) should be invoked on the main thread here.
// func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
//
class BackgroundTransfers: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, URLSessionDelegate {
    let log = LoggerFactory.shared.network(BackgroundTransfers.self)
    typealias TaskID = Int
    
    static let uploader = BackgroundTransfers(basePath: "pics-transfers", sessionID: "com.malliina.pics.transfers", oldTasks: [:])
    
    private let fileManager = FileManager.default
    let basePath: String
    
    private let sessionID: SessionID
    private var downloads: [TaskID: TransferInfo] = [:]
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
        default: return "Unknown"
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
                AnalyticsService.shared.deleted(url: destURL.absoluteURL, reason: "duplicate")
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
            removeTask(taskID, deleteFile: false)
        } else {
            log.info("Task \(taskID) complete.")
            removeTask(taskID, deleteFile: true)
        }
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
        req.httpMethod = HttpClient.post
        for (key, value) in headers {
            req.addValue(value, forHTTPHeaderField: key)
        }
        let task = session.uploadTask(with: req, fromFile: file)
        if deleteOnComplete {
            // folder impl wtf?
            saveUpload(task: UploadTask(id: task.taskIdentifier, folder: file.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, filename: file.lastPathComponent))
        }
        log.info("Uploading \(file) to \(dest.absoluteString)...")
        task.resume()
    }
    
    func saveTask(_ taskID: Int, di: TransferInfo) {
        synchronized {
            self.downloads[taskID] = di
        }
    }
    
    func saveUpload(task: UploadTask) {
        log.info("Saving upload task \(task.id)")
        synchronized {
            PicsSettings.shared.saveUpload(task: task)
        }
    }
    
    func removeTask(_ taskID: Int, deleteFile: Bool) {
        synchronized {
            self.downloads.removeValue(forKey: taskID)
            Task {
                await self.removeUploadedAndUploadNext(id: taskID, deleteFile: deleteFile)
            }
        }
    }
    
    private func removeUploadedAndUploadNext(id: Int, deleteFile: Bool) async {
        if let removed = PicsSettings.shared.removeUpload(id: id) {
            let file = LocalPics.shared.computeUrl(folder: removed.folder, filename: removed.filename)
            do {
                if deleteFile {
                    try fileManager.removeItem(at: file)
                    log.info("Removed \(file) of task \(id).")
                    AnalyticsService.shared.deleted(url: file, reason: "upload")
                    await Backend.shared.library.syncPicsForLatestUser()
                } else {
                    log.info("Not deleting \(file) of task \(id).")
                }
            } catch let err {
                if file.isFile {
                    log.error("Failed to remove \(file) of task \(id). \(err)")
                } else {
                    log.error("Failed to remove \(file) of task \(id). The file does not exist.")
                    await Backend.shared.library.syncPicsForLatestUser()
                }
            }
        } else {
            log.error("Unable to find upload task with ID \(id). Searched \(PicsSettings.shared.uploads.count) tasks.")
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
