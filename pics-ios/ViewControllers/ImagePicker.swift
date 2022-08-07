//
//  ImagePicker.swift
//  pics-ios
//
//  Created by Michael Skogberg on 4.8.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import Photos

struct ImagePicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIImagePickerController
//    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    let onImage: (Picture) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let control = UIImagePickerController()
        control.sourceType = .camera
        control.allowsEditing = false
        control.delegate = context.coordinator
        return control
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, dismissPicker: dismiss)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let log = LoggerFactory.shared.vc(Coordinator.self)
        
        var library: PicsLibrary { Backend.shared.library }
        let user = User()
        
        let parent: ImagePicker
        let dismissPicker: DismissAction
        
        init(_ parent: ImagePicker, dismissPicker: DismissAction) {
            self.parent = parent
            self.dismissPicker = dismissPicker
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismissPicker()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            do {
                try self.handleMedia(info: info)
            } catch let err {
                self.log.info("Failed to save picture. \(err)")
            }
        }
        
        private func handleMedia(info: [UIImagePickerController.InfoKey: Any]) throws {
            log.info("Pic taken, processing...")
            guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
                log.error("Original image is not an UIImage")
                return
            }
            // let what = info[.phAsset]
            if let pha = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset {
                let loc = pha.location
                if let coordinate = loc?.coordinate {
                    log.info("Latitude \(coordinate.latitude) longitude \(coordinate.longitude).")
                } else {
                    log.info("Got PHAsset, but no coordinate.")
                }
            } else {
                log.info("No PHAsset")
            }
            
            let clientKey = ClientKey.random()
            let pic = Picture(image: originalImage, clientKey: clientKey)
            guard let data = originalImage.jpegData(compressionQuality: 1) else {
                log.error("Taken image is not in JPEG format")
                return
            }
            log.info("Saving pic to file, in total \(data.count) bytes...")
            UIImageWriteToSavedPhotosAlbum(originalImage, nil, nil, nil)
            if let user = user.activeUser {
                log.info("Staging then uploading image taken by \(user)...")
                // Copies the picture to a staging folder
                let _ = try LocalPics.shared.saveUserPic(data: data, owner: user, key: clientKey)
                // Attempts to obtain a token and upload the pic
                let _ = library.syncPicsForLatestUser()
            } else {
                // Anonymous upload
                let url = try LocalPics.shared.saveAsJpg(data: data, key: clientKey)
                library.uploadPic(picture: url, clientKey: clientKey)
            }
            parent.onImage(pic)
            dismissPicker()
        }
    }

}

