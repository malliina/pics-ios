//
//  ConfirmVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 03/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class ConfirmVC: BaseVC {
    let log = LoggerFactory.shared.vc(ConfirmVC.self)
    
    let welcomeText = PicsLabel.build(text: "Enter the code sent to the provided email address", alignment: .center, numberOfLines: 0)
    let username = PicsTextField.with(placeholder: "Username")
    let code = PicsTextField.with(placeholder: "Code")
    let confirmButton = PicsButton.create(title: "Confirm")
    let activityIndicator = UIActivityIndicatorView(style: .white)
    
    let resendButton = PicsButton.secondary(title: "Resend Code")
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    var onSuccess: (() -> Void)? = nil
    
    let maxWidth = 500
    let marginSmall = 8
    let marginLarge = 24
    
    init(user: String, onSuccess: @escaping (() -> Void)) {
        super.init(nibName: nil, bundle: nil)
        username.text = user
        self.onSuccess = onSuccess
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        initNav(title: "Confirm")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(ConfirmVC.cancelClicked(_:)))
      
        view.addSubview(welcomeText)
        welcomeText.textColor = .lightText
        welcomeText.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualToSuperview().offset(marginSmall)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.high)
            make.width.lessThanOrEqualTo(maxWidth)
            make.centerX.equalToSuperview()
        }
        
        view.addSubview(username)
        username.snp.makeConstraints { (make) in
            make.top.equalTo(welcomeText.snp.bottom).offset(marginLarge)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(maxWidth).priority(.high)
            make.centerX.equalToSuperview()
        }
        
        view.addSubview(code)
        code.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(maxWidth).priority(.high)
            make.centerX.equalToSuperview()
            make.centerY.lessThanOrEqualToSuperview().priority(.medium)
            make.top.equalTo(username.snp.bottom).offset(marginSmall)
        }
        
        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { (make) in
            make.top.equalTo(code.snp.bottom).offset(marginLarge)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(maxWidth).priority(.high)
            make.centerX.equalToSuperview()
        }
        confirmButton.addTarget(self, action: #selector(ConfirmVC.confirmClicked(_:)), for: .touchUpInside)
        
        view.addSubview(activityIndicator)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.snp.makeConstraints { (make) in
            make.centerX.centerY.equalTo(confirmButton)
        }
        
        view.addSubview(resendButton)
        resendButton.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualTo(confirmButton.snp.bottom).offset(marginLarge).priority(.low)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(maxWidth).priority(.high)
            make.bottom.equalToSuperview().inset(marginLarge)
            make.centerX.equalToSuperview()
        }
        resendButton.addTarget(self, action: #selector(ConfirmVC.resendClicked(_:)), for: .touchUpInside)
    }
    
    @objc func cancelClicked(_ sender: UIBarButtonItem) {
        goBack()
    }
    
    @objc func demo(_ sender: UIBarButtonItem) {
        self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
    }
    
    @objc func confirmClicked(_ sender: UIButton) {
        guard let user = username.text, user != "" else { return }
        guard let code = code.text, code != "" else { return }
        log.info("Attempting to confirm \(user)...")
        showIndicator(on: confirmButton, indicator: activityIndicator)
        pool.getUser(user).confirmSignUp(code, forceAliasCreation: true).continueWith { (task) -> Any? in
            self.onUiThread {
                self.hideIndicator(on: self.confirmButton, indicator: self.activityIndicator)
                if let error = SignupError.check(user: user, error: task.error) {
                    self.presentError(error: error)
                } else {
                    self.log.info("Confirmed \(user).")
                    self.view.window?.rootViewController?.dismiss(animated: true) {
                        self.onSuccess?()
                    }
                }
            }
            return nil
        }
    }
    
    @objc func resendClicked(_ sender: UIButton) {
        guard let user = username.text, user != "" else { return }
        log.info("Resending code for user \(user)...")
        pool.getUser(user).resendConfirmationCode().continueWith { (task) -> Any? in
            self.onUiThread {
                if let error = SignupError.check(user: user, error: task.error) {
                    self.presentError(error: error)
                } else {
                    self.presentAlert(title: "Code sent", message: "A new confirmation code was sent.", buttonText: "Continue")
                }
            }
            return nil
        }
    }
}
