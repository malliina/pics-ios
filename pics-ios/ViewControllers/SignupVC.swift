//
//  SignupVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class SignupVC: BaseVC {
    let log = LoggerFactory.shared.vc(SignupVC.self)
    
    let welcomeText = PicsLabel.build(text: "A valid email address is required", alignment: .center, numberOfLines: 0)
    let username = PicsTextField.with(placeholder: "Email")
    let password = PicsTextField.with(placeholder: "Password", isPassword: true)
    let signupButton = PicsButton.create(title: "Sign up")
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    
    let maxWidth = 500
    let marginSmall = 8
    let marginLarge = 24
    
    let pool = AWSCognitoIdentityUserPool(forKey: AuthVC.PoolKey)
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    init(passwordTask: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?) {
        self.passwordAuthenticationCompletion = passwordTask
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        initNav(title: "Sign Up")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(SignupVC.cancelClicked(_:)))
        
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
        
        view.addSubview(password)
        password.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(maxWidth).priority(.high)
            make.centerX.centerY.equalToSuperview()
            make.top.equalTo(username.snp.bottom).offset(8)
        }
        
        view.addSubview(signupButton)
        signupButton.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualTo(password.snp.bottom).offset(24)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(maxWidth).priority(.high)
            make.centerX.equalToSuperview()
        }
        signupButton.addTarget(self, action: #selector(SignupVC.signupClicked(_:)), for: .touchUpInside)
        
        view.addSubview(activityIndicator)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.snp.makeConstraints { (make) in
            make.centerX.centerY.equalTo(signupButton)
        }
    }
    
    @objc func cancelClicked(_ sender: UIBarButtonItem) {
        goBack()
    }
    
    @objc func signupClicked(_ sender: UIButton) {
        guard let user = username.text, !user.isEmpty else { return }
        guard let pass = password.text, !pass.isEmpty else { return }
        log.info("Attempting to sign up as \(user)...")
        let attributes = [
            AWSCognitoIdentityUserAttributeType(name: "email", value: user)
        ]
        showIndicator(on: signupButton, indicator: activityIndicator)
        pool.signUp(user, password: pass, userAttributes: attributes, validationData: nil).continueWith { (task) -> Any? in
            self.handleSignupResult(task: task)
            return nil
        }
    }
    
    func handleSignupResult(task: AWSTask<AWSCognitoIdentityUserPoolSignUpResponse>) {
        onUiThread {
            self.hideIndicator(on: self.signupButton, indicator: self.activityIndicator)
            if let error = SignupError.check(user: self.username.text ?? "", error: task.error) {
                self.presentError(error: error)
            } else {
                if let response = task.result, let name = response.user.username {
                    self.log.info("Created \(name).")
                    
                    if response.user.confirmedStatus == .confirmed {
                        self.view.window?.rootViewController?.dismiss(animated: true) {
                            self.onSignupDone()
                        }
                    } else {
                        self.log.info("Going to confirm page for \(name)...")
                        self.presentModally(vc: ConfirmVC(user: name, onSuccess: self.onSignupDone))
                    }
                }
            }
        }
    }
    
    func onSignupDone() {
        log.info("Signup done")
        let creds = PasswordCredentials(user: self.username.text ?? "", pass: self.password.text ?? "")
        self.passwordAuthenticationCompletion?.set(result: creds.toCognito())
    }
}
