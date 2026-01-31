import SwiftUI

struct PicView: View {
  private let log = LoggerFactory.shared.view(PicView.self)

  @StateObject var vm: PicVM

  let meta: PicMeta
  let isPrivate: Bool

  var backgroundColor: Color { isPrivate ? color.background : color.lightBackground }
  @State var isSharing = false

  @GestureState private var magnifyBy = 1.0
  @State private var magnifyAnchor: UnitPoint = .center

  init(meta: PicMeta, isPrivate: Bool, smalls: DataCache, larges: DataCache) {
    _vm = StateObject(wrappedValue: PicVM(meta: meta, smalls: smalls, larges: larges))
    self.meta = meta
    self.isPrivate = isPrivate
  }

  var body: some View {
    ZStack {
      backgroundColor
        .edgesIgnoringSafeArea(.all)
        .task {
          await vm.loadImage()
        }
      if let data = vm.data, let uiImage = UIImage(data: data) {
        if #available(iOS 17.0, *) {
          let magnifyGesture = MagnifyGesture()
            .updating($magnifyBy) { value, gestureState, transaction in
              gestureState = value.magnification
              magnifyAnchor = value.startAnchor
            }
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .scaleEffect(magnifyBy, anchor: magnifyAnchor)
            .gesture(magnifyGesture)
        } else {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
        }
      } else {
        ProgressView()
      }
    }
  }
}

struct PicPreviews: PicsPreviewProvider, PreviewProvider {
  static var preview: some View {
    Text("Todo")
  }
}
