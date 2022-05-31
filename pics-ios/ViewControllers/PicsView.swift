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

class PicViewDelegate: PicDelegate {
    func remove(key: ClientKey) {
    }
    
    func block(key: ClientKey) {
        
    }
}

struct PicsView<T>: View where T: PicsVMLike {
    let log = LoggerFactory.shared.vc(PicsView.self)
    
    @ObservedObject var viewModel: T
    
    @State private var picNavigationBarHidden = true
    @State private var showProfile = false
    @State private var showHelp = false
    
    let user = User()
    
    var body: some View {
        GeometryReader { geometry in
            grid(geometry: geometry).onAppear {
                viewModel.load()
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
                        PicPagingView(pics: viewModel.pics.map { p in Picture(meta: p) }, startIndex: index, isPrivate: user.isPrivate, delegate: PicViewDelegate())
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
            }.font(.largeTitle)
        }
        .navigationTitle("Pics")
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
            ProfilePopoverView(user: user.activeUser, delegate: ProfileViewDelegate())
        }
    }
}

class ProfileViewDelegate: ProfileDelegate {
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    var picsSettings: PicsSettings { PicsSettings.shared }
    
    func onPublic() {}
    func onPrivate(user: Username) {}
    func onLogout() {
        signOut()
    }
    
    func signOut() {
        pool.currentUser()?.signOut()
        pool.clearLastKnownUser()
        picsSettings.activeUser = nil
//        self.collectionView?.backgroundView = nil
//        self.navigationController?.navigationBar.isHidden = true
//        resetData()
//        loadPics(for: activeUser)
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
