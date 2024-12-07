import Combine
import Foundation

class PicVM: ObservableObject {
  private let log = LoggerFactory.shared.vc(PicVM.self)
  let meta: PicMeta
  
  let smalls: DataCache
  let larges: DataCache
  
  var downloader: Downloader { Downloader.shared }
  
  @Published var data: Data?
  
  init(meta: PicMeta, smalls: DataCache, larges: DataCache) {
    self.meta = meta
    self.smalls = smalls
    self.larges = larges
  }
  
  func loadImage() async {
    guard data == nil else { return }
    let key = meta.key
    if let large = larges.search(key: key) {
      await update(data: large)
    } else {
      if let small = smalls.search(key: key) {
        await update(data: small)
      }
      do {
        if meta.large.isFileURL {
          log.info("Large \(meta.large) is a file URL.")
          let largeData = try Data(contentsOf: meta.large)
          await update(data: largeData)
        } else {
          if data == nil {
            let smallResult = try await downloader.download(url: meta.small)
            await update(data: smallResult)
            smalls.put(key: key, data: smallResult)
          }
          let result = try await downloader.download(url: meta.large)
          log.info("Downloaded large \(key) from \(meta.large).")
          await update(data: result)
          larges.put(key: key, data: result)
        }
      } catch {
        log.error("Failed to download \(key) \(error)")
      }
    }
  }
  
  @MainActor
  private func update(data: Data) {
    self.data = data
  }
}
