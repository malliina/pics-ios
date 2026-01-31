import Foundation
import MessageUI
import SwiftUI

struct PicPageView<T>: View where T: PicsVMLike {
  private let log = LoggerFactory.shared.view(PicPageView.self)
  @Environment(\.dismiss) private var dismiss

  @ObservedObject var viewModel: T
  let isPrivate: Bool
  @State private var active: PicMeta

  @State var showActions = false
  @State var showShare = false
  @State var showEmail = false
  @State var showAbuseInstructions = false

  init(viewModel: T, startPic: PicMeta, isPrivate: Bool) {
    self.viewModel = viewModel
    self.isPrivate = isPrivate
    _active = .init(initialValue: startPic)
  }

  var drag: some Gesture {
    DragGesture(minimumDistance: 20, coordinateSpace: .global).onEnded { value in
      let horizontalAmount = value.translation.width
      let verticalAmount = value.translation.height

      if abs(horizontalAmount) > abs(verticalAmount) {
        // horizontal swipe
      } else {
        let isUp = verticalAmount < 0
        if isUp {
          dismiss()
        }
      }
    }
  }

  var body: some View {
    TabView(selection: $active) {
      ForEach(viewModel.pics) { pic in
        PicView(
          meta: pic, isPrivate: isPrivate, smalls: viewModel.cacheSmall,
          larges: viewModel.cacheLarge
        )
        .tag(pic)
        .gesture(drag)
      }
    }
    .tabViewStyle(.page)
    .navigationTitle(title())
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        Button {
          showActions.toggle()
        } label: {
          Image(systemName: "square.and.pencil")
            .renderingMode(.template)
        }
        .confirmationDialog(
          "Actions for this image", isPresented: $showActions, titleVisibility: .visible,
          presenting: active
        ) { meta in
          if isPrivate {
            let access = meta.visibility == .publicAccess ? AccessValue.priv : AccessValue.pub
            Button("Make \(access.value)") {
              Task {
                if let updated = await viewModel.modify(meta: meta, access: access) {
                  active = updated
                }
              }
            }
          }
          Button("Copy link URL") {
            UIPasteboard.general.string = meta.url.absoluteString
          }
          Button("Open in Safari") {
            if !meta.url.isFileURL {
              UIApplication.shared.open(meta.url)
            } else {
              log.warn("Refusing to open a file URL in browser.")
            }
          }
          Button("Report objectionable content") {
            if MFMailComposeViewController.canSendMail() {
              showEmail.toggle()
            } else {
              showAbuseInstructions.toggle()
            }
          }
          Button("Hide from this device") {
            dismiss()
            Task {
              await viewModel.block(key: meta.key)
            }
          }
          if isPrivate {
            Button("Delete image", role: .destructive) {
              dismiss()
              Task {
                await viewModel.remove(key: meta.key)
              }
            }
          }
        }
        .sheet(isPresented: $showEmail) {
          MailRepresentable(meta: active, showEmail: $showEmail)
        }
        .alert(
          "Report Objectionable Content", isPresented: $showAbuseInstructions, presenting: active
        ) { meta in
          Button("OK") {
            showAbuseInstructions.toggle()
          }
        } message: { meta in
          Text(
            "Report objectionable content to \(MailRepresentable.abuseEmail). For reference, the image ID is: \(meta.key.key)."
          )
        }
        Button {
          showShare.toggle()
        } label: {
          Image(systemName: "square.and.arrow.up")
            .renderingMode(.template)
        }
        .popover(isPresented: $showShare) {
          ShareRepresentable(meta: active, larges: viewModel.cacheLarge, isPresenting: $showShare)
        }
      }
    }
  }

  func title() -> String {
    title(pic: active)
  }

  func title(pic: PicMeta) -> String {
    let d = Date(timeIntervalSince1970: Double(pic.added) / 1000)
    let df = DateFormatter()
    df.dateFormat = "y-MM-dd H:mm"
    return df.string(from: d)
  }
}
