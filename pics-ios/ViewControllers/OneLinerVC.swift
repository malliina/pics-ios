//
//  OneLinerVC
//  pics-ios
//
//  Created by Michael Skogberg on 03/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class OneLinerVC: BaseVC {
    let log = LoggerFactory.shared.vc(OneLinerVC.self)
    let label: UILabel
    
    init(text: String) {
        self.label = PicsLabel.build(text: text)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        view.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.centerX.centerY.equalToSuperview()
        }
    }
}
