//
//  Log.swift
//  pics-ios
//
//  Created by Michael Skogberg on 26/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import Foundation

import Foundation
import os.log

class Logger {
    private let osLog: OSLog
    
    init(_ subsystem: String, category: String) {
        osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    func info(_ message: String) {
        write(message, .info)
    }
    
    func warn(_ message: String) {
        write(message, .default)
    }
    
    func error(_ message: String) {
        write(message, .error)
    }
    
    func write(_ message: String, _ level: OSLogType) {
        os_log("%@", log: osLog, type: level, message)
    }
}

class LoggerFactory {
    static let shared = LoggerFactory(packageName: "com.malliina.pics")
    
    let packageName: String
    
    init(packageName: String) {
        self.packageName = packageName
    }
    
    func network(_ className: String) -> Logger {
        return pimp("Network", category: className)
    }
    
    func system(_ className: String) -> Logger {
        return pimp("System", category: className)
    }
    
    func view(_ className: String) -> Logger {
        return pimp("Views", category: className)
    }
    
    func vc(_ className: String) -> Logger {
        return pimp("ViewControllers", category: className)
    }
    
    func pimp(_ suffix: String, category: String) -> Logger {
        return Logger("\(packageName).\(suffix)", category: category)
    }
}
