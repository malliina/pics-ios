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
    let imageView = UIImageView()
    
    let pic: Picture
    
    init(pic: Picture) {
        self.pic = pic
        super.init(nibName: nil, bundle: nil)
        imageView.image = pic.url
        self.edgesForExtendedLayout = []
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
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
    
    func onDownloadComplete(data: Data) {
        if let image = UIImage(data: data) {
            pic.url = image
            onUiThread {
                self.imageView.image = image
            }
        }
    }
}
