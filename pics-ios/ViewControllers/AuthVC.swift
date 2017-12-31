//
//  AuthVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 02/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit
import AWSCognitoIdentityProvider

class AuthVC: BaseVC {
    static let PoolKey = "PicsPool"
    let log = LoggerFactory.shared.vc(AuthVC.self)

    let username = PicsTextField.with(placeholder: "Username")
    let password = PicsTextField.with(placeholder: "Password", isPassword: true)
    let loginButton = PicsButton.create(title: "Log in")
    let signupButton = PicsButton.create(title: "Sign up")
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    var root: PicsVC? = nil
    
    init(root: PicsVC) {
        self.root = root
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initUI() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(AuthVC.cancelClicked(_:)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(AuthVC.demo(_:)))
        initNav(title: "Welcome")
        view.addSubview(username)
        username.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualToSuperview().offset(8)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.centerX.equalToSuperview()
        }
        
        view.addSubview(password)
        password.snp.makeConstraints { (make) in
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.centerX.equalToSuperview()
            make.centerY.lessThanOrEqualToSuperview().priority(.medium)
            make.top.equalTo(username.snp.bottom).offset(8)
        }
        
        view.addSubview(loginButton)
        loginButton.snp.makeConstraints { (make) in
            make.top.equalTo(password.snp.bottom).offset(24)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.centerX.equalToSuperview()
        }
        loginButton.addTarget(self, action: #selector(AuthVC.loginClicked(_:)), for: .touchUpInside)
        
        view.addSubview(activityIndicator)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.snp.makeConstraints { (make) in
            make.centerX.centerY.equalTo(loginButton)
        }
        
        view.addSubview(signupButton)
        signupButton.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualTo(loginButton.snp.bottom).offset(24).priority(.low)
            make.leadingMargin.trailingMargin.equalToSuperview().priority(.medium)
            make.width.lessThanOrEqualTo(500).priority(.high)
            make.bottom.equalToSuperview().inset(24)
            make.centerX.equalToSuperview()
        }
        signupButton.addTarget(self, action: #selector(AuthVC.signupClicked(_:)), for: .touchUpInside)
    }
    
    @objc func loginClicked(_ sender: UIButton) {
        loginWithCurrentInput()
    }
    
    @objc func demo(_ sender: UIBarButtonItem) {
//        let pool = Tokens.shared.pool
//        log.info("current user: \(pool.currentUser()) username \(pool.getUser().username)")
    }
    
    @objc func cancelClicked(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true) {
            if let root = self.root {
                // the login view has already been dismissed, yet no session has been obtained, so we reinitialize
                root.reInit()
            }
        }
    }
    
    func loginWithCurrentInput() {
        log.info("Logging in with current input")
        guard let user = username.text, user != "" else { return }
        guard let pass = password.text, pass != "" else { return }
        loginAs(credentials: PasswordCredentials(user: user, pass: pass))
    }
    
    func loginAs(credentials: PasswordCredentials) {
        log.info("Attempting login as \(credentials.username)...")
        if let completion = passwordAuthenticationCompletion {
            log.info("Authenticating...")
            showIndicator(on: loginButton, indicator: activityIndicator)
            completion.set(result: credentials.toCognito())
        } else {
            log.error("No password completion handler available.")
        }
    }
    
    @objc func signupClicked(_ sender: UIButton) {
        presentModally(vc: SignupVC(passwordTask: self.passwordAuthenticationCompletion))
    }
}

extension AuthVC: AWSCognitoIdentityPasswordAuthentication {
    
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
    }
    
    // so if error == nil, it's successful, except when a new pass is required, it's also nil
    public func didCompleteStepWithError(_ error: Error?) {
        onUiThread {
            self.hideIndicator(on: self.loginButton, indicator: self.activityIndicator)
            if let authError = SignupError.check(user: self.username.text ?? "", error: error) {
                if case .userNotConfirmed(let user) = authError {
                    self.presentModally(vc: ConfirmVC(user: user, onSuccess: self.loginWithCurrentInput))
                } else {
                    self.presentError(error: authError)
                }
            } else {
                self.username.text = nil
                self.password.text = nil
                self.root?.changeStyle(dark: true)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}

class RememberMe: NSObject, AWSCognitoIdentityRememberDevice {
    private let log = LoggerFactory.shared.vc(RememberMe.self)
    
    func getRememberDevice(_ rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>) {
        rememberDeviceCompletionSource.set(result: true)
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        
    }
}
