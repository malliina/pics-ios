import SwiftUI

struct PicView: View {
    private let log = LoggerFactory.shared.vc(PicView.self)
    let meta: PicMeta
    let isPrivate: Bool
    
    let smalls: DataCache
    let larges: DataCache
    var backgroundColor: Color { isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var downloader: Downloader { Downloader.shared }
    @State var data: Data? = nil
    
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
                    data = try Data(contentsOf: meta.large)
                } else {
                    if data == nil {
                        let smallResult = try await downloader.download(url: meta.small)
                        data = smallResult
                        smalls.put(key: key, data: smallResult)
                    }
                    let result = try await downloader.download(url: meta.large)
                    data = result
                    larges.put(key: key, data: result)
                }
            } catch let error {
                log.error("Failed to download image \(error)")
            }
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .edgesIgnoringSafeArea(.all).task {
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
