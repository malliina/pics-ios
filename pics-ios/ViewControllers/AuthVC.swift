//
//  AuthVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class AuthVC: UIViewController {
    let label = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(label)
        label.text = "Hello"
        label.textColor = .white
        label.textAlignment = .center
        label.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
}
