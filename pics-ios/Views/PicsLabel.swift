//
//  PicsLabel.swift
//  pics-ios
//
//  Created by Michael Skogberg on 03/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class PicsLabel {
    static func build(text: String, alignment: NSTextAlignment = .center, numberOfLines: Int = 1) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = alignment
        label.numberOfLines = numberOfLines
        return label
    }
}
