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
    
    func testDiff() {
        let low = [1, 2, 3, 4]
        let high = [3, 4, 5, 6]
        let diff = low.diff(against: high) { (i1, i2) -> Bool in
            i1 == i2
        }
        XCTAssert(diff == [1, 2], "diff works")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testDrop() {
        XCTAssert([1, 2].drop(0) == [1, 2])
        XCTAssert([1, 2].drop(1) == [2])
        XCTAssert([1, 2].drop(2).isEmpty)
        XCTAssert([].drop(100).isEmpty)
    }
    
}
