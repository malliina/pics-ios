//
//  Async.swift
//  pics-ios
//
//  Created by Michael Skogberg on 5.6.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import RxSwift

class Async {
    static func async<T>(from: Single<T>) async throws -> T {
        return try await withCheckedThrowingContinuation { cont in
            let _ = from.subscribe { event in
                switch event {
                case .success(let result): cont.resume(returning: result)
                case .failure(let error): cont.resume(throwing: error)
                }
            }
        }
    }
}
