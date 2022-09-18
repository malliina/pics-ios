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
    
    var backgroundColor: Color { viewModel.isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var titleColor: Color { viewModel.isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
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
            .background(PicsColors.almostBlack)
            .cornerRadius(40)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                grid(geometry: geometry).task {
                    await viewModel.loadPicsAsync(for: PicsSettings.shared.activeUser, initialOnly: true)
                }.overlay(alignment: .bottom) {
                    cameraButton
                }
            }
        }.onChange(of: scenePhase) { phase in
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
    
    private func emptyView() -> some View {
        ZStack {
            PicsColors.background
                .edgesIgnoringSafeArea(.all)
            VStack(alignment: .center) {
                Text("Take a pic when ready!").scaledToFill()
                    .foregroundColor(PicsColors.blueish2)
                Spacer()
                cameraButton
            }
        }
    }
    
    private func nonEmptyView(geometry: GeometryProxy) -> some View {
        let sizeInfo = PicsCell.sizeForItem(minWidthPerItem: PicsVM.preferredItemSize, totalWidth: geometry.size.width)
        let columns: [GridItem] = Array(repeating: .init(.fixed(sizeInfo.sizePerItem.width)), count: sizeInfo.itemsPerRow)
        return ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(Array(viewModel.pics.enumerated()), id: \.element.meta.key) { index, pic in
                    NavigationLink {
                        PicPagingView(pics: viewModel.pics, startIndex: index, isPrivate: user.isPrivate, delegate: PicViewDelegate(viewModel: viewModel))
                            .background(backgroundColor)
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
    }
    
    func grid(geometry: GeometryProxy) -> some View {
        return nonEmptyView(geometry: geometry)
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
                    Image(uiImage: #imageLiteral(resourceName: "HelpIcon"))
                        .renderingMode(.template)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Pics")
                    .font(.headline)
                    .foregroundColor(viewModel.isOnline ? titleColor : Color.red)
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
        .navigationBarTitleDisplayMode(.inline)
//        .toolbarBackground(.visible, for: .navigationBar)
//        .toolbarColorScheme(viewModel.isPrivate ? .dark : .light, for: .navigationBar)
//        .navigationBarColo
        .sheet(isPresented: $showHelp) {
            NavigationView {
                HelpView(isPrivate: user.isPrivate)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfilePopoverView(user: user.activeUser, delegate: ProfileViewDelegate(viewModel: viewModel))
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
            ImagePicker { image in
                viewModel.display(newPics: [image])
            }
            .edgesIgnoringSafeArea(.all)
            .background(backgroundColor)
        }
        .background(backgroundColor)
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
