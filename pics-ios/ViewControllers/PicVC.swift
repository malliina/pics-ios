//
//  PicVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 10/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

class PicVC: BaseVC {
    private let log = LoggerFactory.shared.vc(PicVC.self)
    let imageView = UIImageView()
    
    let pic: Picture
    
    let navHiddenInitially: Bool
    let isPrivate: Bool
    
    var backgroundColor: UIColor { isPrivate ? PicsColors.uiBackground : PicsColors.uiLightBackground }
    var cache: DataCache { DataCache.small }
    
    init(pic: Picture, navHiddenInitially: Bool, isPrivate: Bool) {
        self.pic = pic
        self.navHiddenInitially = navHiddenInitially
        self.isPrivate = isPrivate
        super.init(nibName: nil, bundle: nil)
        self.edgesForExtendedLayout = []
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        // shows navbar on tap
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PicVC.onTap(_:)))
        view.addGestureRecognizer(gestureRecognizer)
        
        // goes back on swipe up
        let swipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(PicVC.onSwipeUp(_:)))
        swipeRecognizer.direction = .up
        view.addGestureRecognizer(swipeRecognizer)
        
        view.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.snp.makeConstraints { (make) in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        imageView.backgroundColor = backgroundColor
        if let image = pic.large {
            log.info("Using large image for \(pic.meta.key)")
            imageView.image = image
        } else {
            // Uses the small image until a larger is available
            if let smallData = cache.search(key: pic.meta.key), let smallImage = UIImage(data: smallData) {
                imageView.image = smallImage
            } else {
                imageView.image = pic.preferred
                if pic.preferred != nil {
                    log.info("Using temp image for \(pic.meta.key)")
                } else {
                    log.info("No pic available for \(pic.meta.key)")
                }
            }
            downloadLarge(pic: pic) { large in
                self.onUiThread {
                    self.imageView.image = large
                }
            }
        }
    }
    
    @objc func onTap(_ sender: UITapGestureRecognizer) {
        navigationController?.setNavigationBarHidden(!(navigationController?.navigationBar.isHidden ?? true), animated: true)
    }
    
    @objc func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
        goToPics()
    }
    
    func goToPics() {
        navigationController?.popViewController(animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func downloadLarge(pic: Picture, onImage: @escaping (UIImage) -> Void) {
        if pic.large == nil {
            Downloader.shared.downloadOrLogError(url: pic.meta.large) { data in
                if let image = UIImage(data: data) {
                    onImage(image)
                }
            }
        }
    }
}
