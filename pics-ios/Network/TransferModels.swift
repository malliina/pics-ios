import Foundation

struct TransferResult {
    let url: URL
    let data: Data?
    let response: URLResponse?
    let error: Error?
    
    var isError: Bool { error != nil }
    var httpResponse: HttpResponse? {
        get {
            if let r = response as? HTTPURLResponse, let d = data {
                return HttpResponse(http: r, data: d)
            } else {
                return nil
            }
        }
    }
}

struct DownloadProgressUpdate: Codable {
    let info: TransferInfo
    let writtenDelta: StorageSize
    let written: StorageSize
    let totalExpected: StorageSize?
    
    var relativePath: String { info.relativePath }
    var destinationURL: URL { info.destinationURL }
    
    var isComplete: Bool? { written == totalExpected }
    
    func copy(_ newTotalExpected: StorageSize) -> DownloadProgressUpdate {
        return DownloadProgressUpdate(info: info, writtenDelta: writtenDelta, written: written, totalExpected: newTotalExpected)
    }
    
    static func initial(info: TransferInfo, size: StorageSize) -> DownloadProgressUpdate {
        return DownloadProgressUpdate(info: info, writtenDelta: StorageSize.Zero, written: StorageSize.Zero, totalExpected: size)
    }
}

struct UploadTasks: Codable {
    let tasks: [UploadTask]
}

struct UploadTask: Codable {
    let id: Int
    let folder: String
    let filename: String
}

struct TransferInfo: Codable {
    let relativePath: RelativePath
    let destinationURL: DestinationURL
    let file: URL
    let deleteOnComplete: Bool
}
