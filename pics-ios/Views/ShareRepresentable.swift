import Foundation
import MessageUI
import SwiftUI
import UIKit

struct ShareRepresentable: UIViewControllerRepresentable {
  private let log = LoggerFactory.shared.view(ShareRepresentable.self)
  let meta: PicMeta
  let larges: DataCache
  @Binding var isPresenting: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let image = context.coordinator.shareable(pic: meta)
    let imageUrl = meta.url
    let activities = UIActivityViewController(
      activityItems: [image ?? imageUrl], applicationActivities: nil)
    activities.completionWithItemsHandler = { _, _, _, _ in
      isPresenting = false
    }
    return activities
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
  }

  typealias UIViewControllerType = UIActivityViewController

  class Coordinator {
    let parent: ShareRepresentable

    init(parent: ShareRepresentable) {
      self.parent = parent
    }

    func shareable(pic: PicMeta) -> UIImage? {
      if let cached = parent.larges.search(key: pic.key), let image = UIImage(data: cached) {
        return image
      } else {
        return nil
      }
    }
  }
}
