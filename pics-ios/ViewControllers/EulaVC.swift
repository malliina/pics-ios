//
//  EulaVC.swift
//  pics-ios
//
//  Created by Michael Skogberg on 28/01/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation
import UIKit

class EulaVC: BaseVC {
    let w: UIWindow
    
    init(w: UIWindow) {
        self.w = w
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        eula()
    }
    
    func eula() {
        let a = UIAlertController(title: "Terms of Usage", message: "There is no tolerance for objectionable content or abusive users. Violators will be blocked from the app. The developers of this app assume all rights to images added to this app. Images may be added or removed at the discretion of the app developers at any time. You must agree to these terms in order to continue using this app.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "I Agree", style: .default) { action in
            PicsSettings.shared.isEulaAccepted = true
            self.proceedToApp()
        })
        a.addAction(UIAlertAction(title: "I Disagree", style: .cancel) { action in
            self.secondaryEula()
        })
        present(a, animated: true, completion: nil)
    }
    
    func secondaryEula() {
        let a = UIAlertController(title: "Agreement Required", message: "You must agree to the terms. Try again.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { action2 in
            self.eula()
        })
        self.present(a, animated: true, completion: nil)
    }
    
    func proceedToApp() {
        do {
            let auths = try AuthHandler.configure(window: w)
            let active = auths.active
            // https://stackoverflow.com/a/63797982/1863674
            active.modalPresentationStyle = .overFullScreen
            active.modalTransitionStyle = .crossDissolve
            // present(auths.active, animated: false, completion: nil)
            show(active, sender: self)
        } catch {
            present(OneLinerVC(text: "Unable to initialize app."), animated: true, completion: nil)
        }
    }
}
