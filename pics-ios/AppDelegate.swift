//
//  AppDelegate.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import UIKit
import AWSCognitoIdentityProvider
import SwiftUI

@main
struct PicsApp: App {
    private let log = LoggerFactory.shared.vc(PicsVM.self)
    @State var isError = false
    
    @State var username: Username? = PicsSettings.shared.activeUser
    
    init() {
        do {
            // Sets up folders, cleans up old pics
            let _ = LocalPics.shared
            try CognitoDelegate.configure()
        } catch {
            isError = true
        }
        updateNav(user: username)
        log.info("App initialized.")
    }
    
    var body: some Scene {
        WindowGroup {
            if isError {
                OneLinerView(text: "Unable to initialize app.")
            } else {
                NavigationView {
                    PicsView(viewModel: PicsVM { user in
                        DispatchQueue.main.async {
                            updateNav(user: user)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                username = user
                            }
                        }
                    })
                }
                .id(username) // https://stackoverflow.com/a/64828640
            }
        }
    }
    
    private func updateNav(user: Username?) {
        UINavigationBar.appearance().barStyle = user != nil ? .black : .default
    }
}

//@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let log = LoggerFactory.shared.system(AppDelegate.self)

    var window: UIWindow?
    
    var transferCompletionHandlers: [String: () -> Void] = [:]
    
    var socket: PicsSocket { Backend.shared.socket }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        AppCenter.start(withAppSecret: "cf2aa399-806a-406e-b72d-f4d6e1978e02", services: [
//            Analytics.self,
//            Crashes.self
//        ])

        
        let _ = LocalPics.shared
        let w = UIWindow(frame: UIScreen.main.bounds)
        window = w
        w.makeKeyAndVisible()
        w.rootViewController = initialView()
        return true
    }
    
    func initialView() -> UIViewController {
        if PicsSettings.shared.isEulaAccepted {
            return eulaAcceptedView()
        } else {
            let eula = EulaView {
                self.log.info("EULA accepted, changing root view...")
                self.window?.rootViewController = self.eulaAcceptedView()
            }
            return UIHostingController(rootView: eula)
        }
    }
    
    private func eulaAcceptedView() -> UIViewController {
        do {
            try CognitoDelegate.configure()
            let nav = UINavigationController()
            let picsViewModel = PicsVM { user in
                nav.navigationBar.barStyle = user != nil ? UIBarStyle.black : .default
            }
            let picsView = PicsView(viewModel: picsViewModel)
            let picsVc = UIHostingController(rootView: picsView)
            nav.pushViewController(picsVc, animated: false)
            return nav
        } catch {
            return UIHostingController(rootView: OneLinerView(text: "Unable to initialize app."))
        }
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        log.info("Complete: \(identifier)")
        transferCompletionHandlers[identifier] = completionHandler
        BackgroundTransfers.uploader.setup()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
//        log.info("willResignActive")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        log.info("didEnterBackground")
        socket.disconnect()
        // Saves local pics
//        PicsDatabase.shared.save()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        log.info("willEnterForeground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        // Reload pics, merge changes with local
        log.info("didBecomeActive")
        socket.reconnect()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
