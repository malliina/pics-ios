//
//  PicCell.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class PicCell: UICollectionViewCell {
    let imageView: UIImageView
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        super.init(frame: frame)
        initView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        imageView = UIImageView()
        super.init(coder: aDecoder)
        initView()
    }
    
    func initView() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
    }
}
