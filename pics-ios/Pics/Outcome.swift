//
//  Outcome.swift
//  pics-ios
//
//  Created by Michael Skogberg on 20/03/2018.
//  Copyright © 2018 Michael Skogberg. All rights reserved.
//

import Foundation

enum Outcome<T> {
    case failure(AppError)
    case success(T)
    
    static func fail<T>(_ l: AppError) -> Outcome<T> {
        return .failure(l)
    }
    
    static func succeed<T>(_ r: T) -> Outcome<T> {
        return .success(r)
    }
}

extension Outcome {
    func map<U>(_ code: (T) -> U) -> Outcome<U> {
        switch self {
        case .failure(let appError): return Outcome.fail(appError)
        case .success(let t): return Outcome.succeed(code(t))
        }
    }
}
