//
//  Devices.swift
//  pics-ios
//
//  Created by Michael Skogberg on 10/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class Devices {
    static var isIpad: Bool {
        get {
            let traits = UIScreen.main.traitCollection
            return traits.horizontalSizeClass == .regular && traits.verticalSizeClass == .regular
        }
    }
}
