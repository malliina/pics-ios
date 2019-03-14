//
//  codables.swift
//  pics-ios
//
//  Created by Michael Skogberg on 14/03/2019.
//  Copyright © 2019 Michael Skogberg. All rights reserved.
//

import Foundation

protocol ValueCodable: Codable, CustomStringConvertible {
    init(_ value: String)
    var value: String { get }
}

extension ValueCodable {
    var description: String { return value }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(raw)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

protocol ValidatedValueCodable: Codable, CustomStringConvertible {
    init(_ value: String) throws
    var value: String { get }
}

extension ValidatedValueCodable {
    var description: String { return value }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        try self.init(raw)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
