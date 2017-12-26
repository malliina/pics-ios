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
    
    var navHiddenInitially: Bool
    
    init(pic: Picture, navHiddenInitially: Bool) {
        self.pic = pic
        self.navHiddenInitially = navHiddenInitially
        super.init(nibName: nil, bundle: nil)
        imageView.image = pic.url
        self.edgesForExtendedLayout = []
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        navigationController?.setNavigationBarHidden(navHiddenInitially, animated: true)
        
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
        // Uses the small image until a larger is available
        if let image = pic.large {
            imageView.image = image
        } else {
            imageView.image = pic.small
            Downloader.shared.download(url: pic.meta.large) { data in
                self.onDownloadComplete(data: data)
            }
        }
    }
    
    @objc func onTap(_ sender: UITapGestureRecognizer) {
        navigationController?.setNavigationBarHidden(!(navigationController?.navigationBar.isHidden ?? true), animated: true)
    }
    
    @objc func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
        navigationController?.popViewController(animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func onDownloadComplete(data: Data) {
        if let image = UIImage(data: data) {
            pic.url = image
            onUiThread {
                self.imageView.image = image
            }
        }
    }
}
