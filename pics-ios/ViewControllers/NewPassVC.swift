//
//  NewPassVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class NewPassVC: BaseVC {
    static let PoolKey = "PicsPool"
    let log = LoggerFactory.shared.vc(NewPassVC.self)

    let password = PicsTextField.with(placeholder: "Password", keyboardAppearance: .dark, isPassword: true)
    let saveButton = PicsButton.create(title: "Save")
    
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    var newPassCompletion: AWSTaskCompletionSource<AWSCognitoIdentityNewPasswordRequiredDetails>?
    
    var root: PicsVC? = nil
    
    init(root: PicsVC) {
        self.root = root
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NewPassVC.cancelClicked(_:)))
        initNav(title: "Set New Password")
        view.addSubview(password)
        password.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.centerX.centerY.equalToSuperview()
        }
        
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { (make) in
            make.top.equalTo(password.snp.bottom).offset(24)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(500).priority(.high)
        }
        saveButton.addTarget(self, action: #selector(AuthVC.loginClicked(_:)), for: .touchUpInside)
    }
    
    @objc func loginClicked(_ sender: UIButton) {
        guard let pass = password.text, pass != "" else { return }
        log.info("Submitting new pass...")
        let newPassDetails = AWSCognitoIdentityNewPasswordRequiredDetails(proposedPassword: pass, userAttributes: [:])
        // triggers didCompleteNewPasswordStepWithError
        newPassCompletion?.set(result: newPassDetails)
    }
    
    @objc func cancelClicked(_ sender: UIBarButtonItem) {
        self.dismiss(animated: false) {
            if let root = self.root {
                // the login view has already been dismissed, yet no session has been obtained, so we reinitialize
                root.reInit()
            }
        }
    }
}

extension NewPassVC: AWSCognitoIdentityNewPasswordRequired {
    func getNewPasswordDetails(_ newPasswordRequiredInput: AWSCognitoIdentityNewPasswordRequiredInput, newPasswordRequiredCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityNewPasswordRequiredDetails>) {
        self.newPassCompletion = newPasswordRequiredCompletionSource
    }
    
    func didCompleteNewPasswordStepWithError(_ error: Error?) {
        if let error = SignupError.check(user: "", error: error) {
            presentError(error: error)
        } else {
            onUiThread {
                self.password.text = nil
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}
