import AWSCognitoIdentityProvider
import Foundation
import SwiftUI

struct PicsView<T>: View where T: PicsVMLike {
  let log = LoggerFactory.shared.vc(PicsView.self)

  @Environment(\.scenePhase) private var scenePhase

  @ObservedObject var viewModel: T

  @State private var picsNavigationBarHidden = false
  @State private var picNavigationBarHidden = true
  @State private var showProfile = false
  @State private var showHelp = false
  @State private var showCamera = false

  @State var showLogin = false
  @State var showNewPass = false

  var backgroundColor: Color { viewModel.isPrivate ? color.background : color.lightBackground }
  var titleColor: Color { viewModel.isPrivate ? color.almostLight : color.almostBlack }

  let user = User()
  let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

  init(viewModel: T) {
    self.viewModel = viewModel
  }

  private var cameraButton: some View {
    Button {
      showCamera.toggle()
    } label: {
      HStack {
        Image(systemName: "camera")
          .renderingMode(.template)
        Text("Take pic")
          .fontWeight(.semibold)
          .font(.title)
        Image(systemName: "camera")
          .renderingMode(.template)
          .opacity(0)
      }
      .padding()
      .frame(minWidth: 220)
      .background(color.almostBlack)
      .cornerRadius(40)
    }
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        grid(geometry: geometry)
          .task {
            await viewModel.prep()
          }
          .overlay(alignment: .bottom) {
            cameraButton.padding(.bottom, Devices.isIpad ? 24 : 0)
          }
      }
    }
    .onChange(of: scenePhase) { phase in
      if phase == .inactive {
        // when resuming app, the resume scenes are:
        // background -> inactive -> active
        viewModel.disconnect()
      }
      if phase == .active {
        viewModel.connect()
      }
    }
  }

  @ViewBuilder
  private func contentView(geometry: GeometryProxy) -> some View {
    if viewModel.pics.isEmpty {
      emptyView()
    } else {
      nonEmptyView(geometry: geometry)
    }
  }

  private func emptyView() -> some View {
    VStack(alignment: .center) {
      Spacer()
      Text("Take a pic when ready!")
        .foregroundColor(color.blueish2)
      Spacer()
    }.frame(maxWidth: .infinity)
  }

  private func nonEmptyView(geometry: GeometryProxy) -> some View {
    let sizeInfo = SizeInfo.forItem(
      minWidthPerItem: PicsVM.preferredItemSize, totalWidth: geometry.size.width)
    let columns: [GridItem] = Array(
      repeating: .init(.fixed(sizeInfo.sizePerItem.width)), count: sizeInfo.itemsPerRow)
    return ScrollView {
      LazyVGrid(columns: columns) {
        ForEach(viewModel.pics) { pic in
          NavigationLink {
            PicPageView(
              viewModel: viewModel,
              startPic: pic,
              isPrivate: user.isPrivate
            )
            .background(backgroundColor)
            .navigationBarHidden(picNavigationBarHidden)
            .onTapGesture {
              picNavigationBarHidden = !picNavigationBarHidden
            }
          } label: {
            // SwiftUI comes with AsyncImage, but not sure how to cache resources (URLs)
            // it fetches, so it's not used.
            CachedImage(
              meta: pic, size: sizeInfo.sizePerItem, cache: viewModel.cacheSmall,
              animate: viewModel.animatePics)
            //                            .animation(.easeInOut)
            //                        AsyncImage(url: pic.meta.small)
          }
        }
        if viewModel.hasMore {
          ProgressView().task {
            await viewModel.loadMore()
          }
        }
      }.font(.largeTitle)
    }
  }

  func grid(geometry: GeometryProxy) -> some View {
    contentView(geometry: geometry)
      .toolbar {
        ToolbarItemGroup(placement: .navigationBarLeading) {
          Button {
            showProfile.toggle()
          } label: {
            Image(uiImage: #imageLiteral(resourceName: "ProfileIcon"))
              .renderingMode(.template)
          }
          Button {
            showHelp.toggle()
          } label: {
            Image(uiImage: #imageLiteral(resourceName: "HelpIcon"))
              .renderingMode(.template)
          }
        }
        ToolbarItem(placement: .principal) {
          Text("Pics")
            .font(.headline)
            .foregroundColor(viewModel.isOnline ? titleColor : titleColor.opacity(0.4))
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
          if isCameraAvailable {
            Button {
              showCamera.toggle()
            } label: {
              Image(systemName: "camera")
                .renderingMode(.template)
            }
          }
          Button {
            Task {
              await viewModel.reload()
            }
          } label: {
            Image(systemName: "cloud")
              .renderingMode(.template)
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showHelp) {
        NavigationView {
          HelpView(isPrivate: user.isPrivate)
        }
      }
      .sheet(isPresented: $showProfile) {
        ProfilePopoverView(
          user: user.activeUser, delegate: ProfileViewDelegate(viewModel: viewModel))
      }
      .sheet(isPresented: $viewModel.showLogin) {
        NavigationView {
          LoginView(handler: viewModel.loginHandler)
        }
      }
      .sheet(isPresented: $viewModel.showNewPass) {
        NavigationView {
          NewPassView(handler: viewModel.loginHandler)
        }
      }
      .fullScreenCover(isPresented: $showCamera) {
        ImagePicker { meta, image in
          Task {
            await viewModel.display(newPics: [meta])
          }
        }
        .edgesIgnoringSafeArea(.all)
        .background(backgroundColor)
      }
      .background(backgroundColor)
  }
}

class ProfileViewDelegate<T>: ProfileDelegate where T: PicsVMLike {
  let log = LoggerFactory.shared.vc(ProfileViewDelegate.self)
  let viewModel: T

  init(viewModel: T) {
    self.viewModel = viewModel
  }

  func onPublic() async {
    await viewModel.onPublic()
  }

  func onPrivate(user: Username) async {
    await viewModel.onPrivate(user: user)
  }

  func onLogout() async {
    await viewModel.signOut()
  }
}

struct PicsViewPreviews: PicsPreviewProvider, PreviewProvider {
  static var preview: some View {
    PicsView(viewModel: PreviewPicsVM())
  }
}
