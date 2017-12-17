//
//  PicsButton.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class PicsButton {
    static let blueish = PicsColors.buttonText
    
    static func create(title: String) -> UIButton {
        let button = UIButton(type: .roundedRect)
        button.setTitle(title, for: .normal)
        button.layer.borderColor = blueish.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 20
        button.titleLabel?.font = UIFont.systemFont(ofSize: 28)
        return button
    }
    
    static func secondary(title: String) -> UIButton {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.setTitleColor(blueish, for: .normal)
        return button
    }
}
