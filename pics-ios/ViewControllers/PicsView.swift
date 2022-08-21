//
//  PicsView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 15.5.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

class PicViewDelegate <T> : PicDelegate where T: PicsVMLike {
    let viewModel: T
    
    init(viewModel: T) {
        self.viewModel = viewModel
    }
    
    func remove(key: ClientKey) {
        viewModel.remove(key: key)
    }
    
    func block(key: ClientKey) {
        viewModel.block(key: key)
    }
}

class DemoData: ObservableObject {
    @Published var names: [String] = ["https://pics.malliina.com/jnmczfc.jpg?s=s"]
}

struct DemoListView: View {
    @EnvironmentObject var viewModel: DemoData
    
    var body: some View {
        VStack {
            Button("Add") {
                viewModel.names.append("https://pics.malliina.com/jnmczfc.jpg?s=s")
            }
            List {
                ForEach(viewModel.names, id: \.self) { task in
                    AsyncImage(url: URL(string: task))
                }
            }
        }
    }
}

struct PicsView<T>: View where T: PicsVMLike {
    let log = LoggerFactory.shared.vc(PicsView.self)
    
    @ObservedObject var viewModel: T
    
    @State private var picsNavigationBarHidden = false
    @State private var picNavigationBarHidden = true
    @State private var showProfile = false
    @State private var showHelp = false
    @State private var showCamera = false
    
    var backgroundColor: UIColor { viewModel.isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var titleColor: UIColor { viewModel.isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    let user = User()
    let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    
    init(viewModel: T) {
        self.viewModel = viewModel
    }
    
    var body2: some View {
        DemoListView().environmentObject(DemoData())
    }
    
    var body: some View {
        GeometryReader { geometry in
            grid(geometry: geometry).task {
                await viewModel.loadPicsAsync(for: PicsSettings.shared.activeUser, initialOnly: true)
            }
        }
    }
    
    func grid(geometry: GeometryProxy) -> some View {
        let sizeInfo = PicsCell.sizeForItem(minWidthPerItem: PicsVC.preferredItemSize, totalWidth: geometry.size.width)
        let columns: [GridItem] = Array(repeating: .init(.fixed(sizeInfo.sizePerItem.width)), count: sizeInfo.itemsPerRow)
        return ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(Array(viewModel.pics.enumerated()), id: \.element.meta.key) { index, pic in
                    NavigationLink {
                        PicPagingView(pics: viewModel.pics, startIndex: index, isPrivate: user.isPrivate, delegate: PicViewDelegate(viewModel: viewModel))
                            .background(Color(backgroundColor))
                            .navigationBarHidden(picNavigationBarHidden)
                            .onTapGesture {
                                picNavigationBarHidden = !picNavigationBarHidden
                            }
                    } label: {
                        // SwiftUI comes with AsyncImage, but not sure how to cache resources (URLs)
                        // it fetches, so it's not used.
                        CachedImage(pic: pic, size: sizeInfo.sizePerItem)
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
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    showProfile = !showProfile
                } label: {
                    Image(uiImage: #imageLiteral(resourceName: "ProfileIcon"))
                        .renderingMode(.template)
                }
                Button {
                    showHelp = !showHelp
                } label: {
//                    Image(systemName: "questionmark.circle")
                    Image(uiImage: #imageLiteral(resourceName: "HelpIcon"))
                        .renderingMode(.template)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Pics")
                    .font(.headline)
                    .foregroundColor(viewModel.isOnline ? Color(titleColor) : Color.red)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isCameraAvailable {
                    Button {
                        showCamera = !showCamera
                    } label: {
                        Image(systemName: "camera")
                            .renderingMode(.template)
                    }
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            NavigationView {
                HelpView(isPrivate: user.isPrivate)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfilePopoverView(user: user.activeUser, delegate: ProfileViewDelegate(viewModel: viewModel))
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker { image in
                viewModel.display(newPics: [image])
            }.background(Color(backgroundColor))
        }
        .background(Color(backgroundColor))
    }
}

class ProfileViewDelegate <T> : ProfileDelegate where T: PicsVMLike {
    let log = LoggerFactory.shared.vc(ProfileViewDelegate.self)
    let viewModel: T
    
    init(viewModel: T) {
        self.viewModel = viewModel
    }
    
    func onPublic() {
        viewModel.onPublic()
    }
    
    func onPrivate(user: Username) {
        viewModel.onPrivate(user: user)
    }
    
    func onLogout() {
        signOut()
    }
    
    func signOut() {
        viewModel.signOut()
    }
}

struct PicsView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            PicsView(viewModel: PreviewPicsVM())
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
