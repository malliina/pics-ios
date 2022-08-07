//
//  PicsVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 03/12/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class BaseVC: UIViewController {
    private let log = LoggerFactory.shared.vc(BaseVC.self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PicsColors.background
        initUI()
    }
    
    func initUI() {
        
    }
    
    func presentError(error: SignupError) {
        presentAuthError(error: error)
    }
}

extension UIViewController {
    func showIndicator(on: UIButton, indicator: UIActivityIndicatorView) {
        animated(view: on) {
            on.isHidden = true
            indicator.startAnimating()
        }
    }
    
    func hideIndicator(on: UIButton, indicator: UIActivityIndicatorView) {
        animated(view: on) {
            on.isHidden = false
            indicator.stopAnimating()
        }
    }
    
    func animated(view: UIView, changes: @escaping () -> Void) {
        UIView.transition(with: view, duration: 0.4, options: .transitionCrossDissolve, animations: changes, completion: nil)
    }
    
    func onUiThread(_ f: @escaping () -> Void) {
        DispatchQueue.main.async(execute: f)
    }
    
    func onBackgroundThread(_ f: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async(execute: f)
    }
    
    func goBack() {
        dismiss(animated: true, completion: nil)
    }
    
    func goBackDirectly() {
        dismiss(animated: false, completion: nil)
    }
    
    func presentModally(vc: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        let dest = UINavigationController(rootViewController: vc)
        dest.navigationBar.prefersLargeTitles = true
        self.present(dest, animated: animated, completion: completion)
    }
    
    func presentAuthError(error: SignupError) {
        presentAlert(title: "Authentication error", message: error.message, buttonText: "Retry")
    }
    
    func presentAlert(title: String, message: String, buttonText: String) {
        onUiThread {
            let alertController = UIAlertController(title: title,
                                                    message: message,
                                                    preferredStyle: .alert)
            let retryAction = UIAlertAction(title: buttonText, style: .default, handler: nil)
            alertController.addAction(retryAction)
            self.present(alertController, animated: true, completion:  nil)
        }
    }
    
    func initNav(title: String, large: Bool = true) {
        navigationItem.title = title
        guard let navbar = self.navigationController?.navigationBar else { return }
        navbar.isHidden = false
        navbar.prefersLargeTitles = large
        navbar.isTranslucent = true
    }
}
