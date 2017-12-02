//
//  pics_iosTests.swift
//  pics-iosTests
//
//  Created by Michael Skogberg on 19/11/2017.
//  Copyright © 2017 Michael Skogberg. All rights reserved.
//

import XCTest
@testable import pics_ios

class pics_iosTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let raw = "http://10.0.0.1:9000/pics"
        let url = try! FullUrl.parse(input: raw)
        print("parsed proto \(url.proto)")
        XCTAssert(url.proto == "http", "proto matches")
        XCTAssert(url.host == "10.0.0.1:9000", "host matches")
        XCTAssert(url.uri == "/pics", "pics matches")
        XCTAssert(url.url == raw, "url matches")
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
