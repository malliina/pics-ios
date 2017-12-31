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
    
    let username = PicsTextField.with(placeholder: "Username")
    let code = PicsTextField.with(placeholder: "Code")
    let confirmButton = PicsButton.create(title: "Confirm")
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    
    let resendButton = PicsButton.secondary(title: "Resend Code")
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    var onSuccess: (() -> Void)? = nil
    
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
      
        view.addSubview(username)
        username.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualToSuperview().offset(8)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.centerX.equalToSuperview()
        }
        
        view.addSubview(code)
        code.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.centerX.equalToSuperview()
            make.centerY.lessThanOrEqualToSuperview().priority(.medium)
            make.top.equalTo(username.snp.bottom).offset(8)
        }
        
        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { (make) in
            make.top.equalTo(code.snp.bottom).offset(24)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
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
            make.top.greaterThanOrEqualTo(confirmButton.snp.bottom).offset(24).priority(.low)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.bottom.equalToSuperview().inset(24)
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
