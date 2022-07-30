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
    
    @ObservedObject var viewModel: T
    
    @State private var picsNavigationBarHidden = false
    @State private var picNavigationBarHidden = true
    @State private var showProfile = false
    @State private var showHelp = false
    
    var backgroundColor: UIColor { viewModel.isPrivate ? PicsColors.background : PicsColors.lightBackground }
    var cellBackgroundColor: UIColor { viewModel.isPrivate ? PicsColors.almostBlack : PicsColors.almostLight }
    var textColor: UIColor { viewModel.isPrivate ? .lightText : .darkText }
    var titleTextColor: UIColor { viewModel.isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    let user = User()
    
//    init(viewModel: T) {
//        self.viewModel = viewModel
//        log.info("Init PicsView")
//        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.yellow]
//    }
    
    var body: some View {
        GeometryReader { geometry in
            grid(geometry: geometry).onAppear {
                viewModel.loadPics(for: PicsSettings.shared.activeUser)
            }
        }
    }
    
    func grid(geometry: GeometryProxy) -> some View {
        let sizeInfo = PicsCell.sizeForItem(minWidthPerItem: PicsVC.preferredItemSize, totalWidth: geometry.size.width)
        let columns: [GridItem] = Array(repeating: .init(.fixed(sizeInfo.sizePerItem.width)), count: sizeInfo.itemsPerRow)
        return ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(Array(viewModel.pics.enumerated()), id: \.offset) { index, pic in
                    NavigationLink {
                        PicPagingView(pics: viewModel.pics.map { p in Picture(meta: p) }, startIndex: index, isPrivate: user.isPrivate, delegate: PicViewDelegate(viewModel: viewModel))
                            .background(Color(backgroundColor))
                            .navigationBarHidden(picNavigationBarHidden)
                            .onTapGesture {
                                picNavigationBarHidden = !picNavigationBarHidden
                            }
                    } label: {
                        AsyncImage(url: pic.medium) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill().frame(width: sizeInfo.sizePerItem.width, height: sizeInfo.sizePerItem.height).clipped()
                            } else if phase.error != nil {
                                Color.red // Indicates an error.
                            } else {
                                ProgressView()
                            }
                        }.frame(width: sizeInfo.sizePerItem.width, height: sizeInfo.sizePerItem.height)
                    }
                }
                if viewModel.hasMore {
                    ProgressView().onAppear {
                        viewModel.loadMore()
                    }
                }
            }.font(.largeTitle)
        }
        .background(Color(backgroundColor))
        .navigationTitle("Pics")
        .foregroundColor(Color.blue)
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
        }
        .sheet(isPresented: $showHelp) {
            NavigationView {
                HelpView(isPrivate: user.isPrivate) {
                    showHelp = false
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfilePopoverView(user: user.activeUser, delegate: ProfileViewDelegate(viewModel: viewModel))
        }
    }
}

class ProfileViewDelegate <T> : ProfileDelegate where T: PicsVMLike {
    let log = LoggerFactory.shared.vc(ProfileViewDelegate.self)
    let viewModel: T
    
    var titleTextColor: UIColor { viewModel.isPrivate ? PicsColors.almostLight : PicsColors.almostBlack }
    
    init(viewModel: T) {
        self.viewModel = viewModel
    }
    
    func onPublic() {
        viewModel.onPublic()
//        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: PicsColors.almostBlack]
    }
    func onPrivate(user: Username) {
        viewModel.onPrivate(user: user)
//        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: PicsColors.almostLight]
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
