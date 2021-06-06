//
//  AppDelegate.swift
//  pics-ios
//
//  Created by Michael Skogberg on 19/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import UIKit
import AWSCognito
import AWSCognitoIdentityProvider
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let log = LoggerFactory.shared.system(AppDelegate.self)

    var window: UIWindow?
    var auths: AuthHandler?
    
    var transferCompletionHandlers: [String: () -> Void] = [:]

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        AppCenter.start(withAppSecret: "cf2aa399-806a-406e-b72d-f4d6e1978e02", services: [
//            Analytics.self,
//            Crashes.self
//        ])
        // Cleans up old pics
        let _ = LocalPics.shared
        let w = UIWindow(frame: UIScreen.main.bounds)
        window = w
        w.makeKeyAndVisible()
        w.rootViewController = initialView(w: w)
        return true
    }
    
    func initialView(w: UIWindow) -> UIViewController {
        if PicsSettings.shared.isEulaAccepted {
            do {
                let authHandler = try AuthHandler.configure(window: w)
                auths = authHandler
                return authHandler.active
            } catch {
                return OneLinerVC(text: "Unable to initialize app.")
            }
        } else {
            return EulaVC(w: w)
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
        
//        log.info("didEnterBackground")
        // Saves local pics
//        PicsDatabase.shared.save()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        // Reconnects socket, loads any new pics, etc
        LifeCycle.shared.renderer?.reconnectAndSync()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        // Reload pics, merge changes with local
//        log.info("didBecomeActive")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}
