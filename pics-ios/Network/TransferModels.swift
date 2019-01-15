//
//  TransferModels.swift
//  pics-ios
//
//  Created by Michael Skogberg on 15/01/2019.
//  Copyright © 2019 Michael Skogberg. All rights reserved.
//

import Foundation

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
    let info: TransferInfo
    let writtenDelta: StorageSize
    let written: StorageSize
    let totalExpected: StorageSize?
    
    var relativePath: String { return info.relativePath }
    var destinationURL: URL { return info.destinationURL }
    
    var isComplete: Bool? { get { return written == totalExpected } }
    
    init(info: TransferInfo, writtenDelta: StorageSize, written: StorageSize, totalExpected: StorageSize?) {
        self.info = info
        self.writtenDelta = writtenDelta
        self.written = written
        self.totalExpected = totalExpected
    }
    
    func copy(_ newTotalExpected: StorageSize) -> DownloadProgressUpdate {
        return DownloadProgressUpdate(info: info, writtenDelta: writtenDelta, written: written, totalExpected: newTotalExpected)
    }
    
    static func initial(info: TransferInfo, size: StorageSize) -> DownloadProgressUpdate {
        return DownloadProgressUpdate(info: info, writtenDelta: StorageSize.Zero, written: StorageSize.Zero, totalExpected: size)
    }
}

struct UploadTask {
    let id: Int
    let folder: String
    let filename: String
    
    static let Tasks = "tasks"
    static let Id = "id"
    static let Folder = "folder"
    static let Filename = "filename"
    
    static func write(task: UploadTask) -> [String: AnyObject] {
        return [
            Id: task.id as AnyObject,
            Folder: task.folder as AnyObject,
            Filename: task.filename as AnyObject
        ]
    }
    
    static func parseList(obj: AnyObject) throws -> [UploadTask] {
        let dict = try Json.readObject(obj)
        let tasks: [NSDictionary] = try Json.readOrFail(dict, UploadTask.Tasks)
        return try tasks.map(UploadTask.parse)
    }
    
    static func parse(_ obj: AnyObject) throws -> UploadTask {
        if let dict = obj as? NSDictionary {
            let id = try Json.readInt(dict, Id)
            let folder = try Json.readString(dict, Folder)
            let filename = try Json.readString(dict, Filename)
            return UploadTask(id: id, folder: folder, filename: filename)
        }
        throw JsonError.invalid("task", obj)
    }
}

open class TransferInfo {
    let relativePath: RelativePath
    let destinationURL: DestinationURL
    let file: URL
    let deleteOnComplete: Bool
    
    public init(relativePath: RelativePath, destinationURL: DestinationURL, file: URL, deleteOnComplete: Bool) {
        self.relativePath = relativePath
        self.destinationURL = destinationURL
        self.file = file
        self.deleteOnComplete = deleteOnComplete
    }
}
