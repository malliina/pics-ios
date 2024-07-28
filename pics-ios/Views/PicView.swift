import SwiftUI

struct PicView: View {
  private let log = LoggerFactory.shared.view(PicView.self)
  let meta: PicMeta
  let isPrivate: Bool

  let smalls: DataCache
  let larges: DataCache
  @Binding var transitioning: Bool
  var backgroundColor: Color { isPrivate ? color.background : color.lightBackground }
  var downloader: Downloader { Downloader.shared }
  @State var data: Data? = nil
  @State var isSharing = false

  @MainActor
  func loadImage() async {
    guard data == nil else { return }
    let key = meta.key
    if let large = larges.search(key: key) {
      data = large
    } else {
      data = smalls.search(key: key)
      do {
        if meta.large.isFileURL {
          log.info("Large \(meta.large) is a file URL.")
          data = try Data(contentsOf: meta.large)
        } else {
          if data == nil {
            let smallResult = try await downloader.download(url: meta.small)
            data = smallResult
            smalls.put(key: key, data: smallResult)
          }
          let result = try await downloader.download(url: meta.large)
          log.info("Downloaded large \(key) from \(meta.large).")
          data = result
          larges.put(key: key, data: result)
        }
      } catch {
        log.error("Failed to download \(key) \(error)")
      }
    }
  }

  var body: some View {
    ZStack {
      backgroundColor
        .edgesIgnoringSafeArea(.all)
        .task {
          await loadImage()
        }
      if let data = data, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFit()
      } else {
        ProgressView()
      }
    }
  }
}

struct PicView_Previews: PreviewProvider {
  //    let pic = UIImage(named: "AppIcon")
  static var previews: some View {
    //        PicView()
    Text("Todo")
  }
}
