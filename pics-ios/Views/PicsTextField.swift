//
//  PicTextField.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class PicsTextField: UITextField, UITextFieldDelegate {
    var placeholderText: String? {
        get { return placeholder }
        set(newPlaceholder) { attributedPlaceholder = NSAttributedString(string: newPlaceholder ?? "", attributes: [NSAttributedString.Key.foregroundColor: PicsColors.placeholder]) }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initUI()
    }
    
    static func with(placeholder: String, keyboardAppearance: UIKeyboardAppearance = .dark, isPassword: Bool = false) -> PicsTextField {
        let field = PicsTextField()
        field.placeholderText = placeholder
        field.isSecureTextEntry = isPassword
        field.keyboardAppearance = keyboardAppearance
        return field
    }
    
    fileprivate func initUI() {
        delegate = self
        backgroundColor = PicsColors.inputBackground
        textColor = PicsColors.inputText
        borderStyle = .roundedRect
        font = UIFont.systemFont(ofSize: 28)
        autocorrectionType = .no
        autocapitalizationType = .none
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
