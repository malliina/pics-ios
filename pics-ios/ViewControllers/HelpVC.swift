//
//  HelpVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 28/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class HelpVC: BaseVC {
    let developedByLabel = PicsLabel.build(text: "Developed by Michael Skogberg.", alignment: .center, numberOfLines: 0)
    let contactLabel = PicsLabel.build(text: "You can reach me at info@skogberglabs.com. To report objectionable images or copyright violations: Tap the image, then tap it again to open the navigation bar and select an appropriate action from the action button. Abusive images will be removed within 24 hours.", alignment: .center, numberOfLines: 0)
    
    let isPrivate: Bool
    let maxWidth = 600
    
    var textColor: UIColor { return isPrivate ? .lightText : .darkText }
    var backgroundColor: UIColor { return isPrivate ? PicsColors.background : PicsColors.lightBackground }
    
    init(isPrivate: Bool) {
        self.isPrivate = isPrivate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(cancelClicked(_:)))
        view.backgroundColor = backgroundColor
        navigationItem.title = "Help"
        view.addSubview(developedByLabel)
        developedByLabel.textColor = textColor
        developedByLabel.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.centerX.equalToSuperview()
            make.topMargin.equalToSuperview().offset(24)
        }
        view.addSubview(contactLabel)
        contactLabel.textColor = textColor
        contactLabel.snp.makeConstraints { (make) in
            make.top.equalTo(developedByLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.leadingMargin.trailingMargin.equalToSuperview()
        }
    }
    
    @objc func cancelClicked(_ sender: UIBarButtonItem) {
        goBack()
    }
}
