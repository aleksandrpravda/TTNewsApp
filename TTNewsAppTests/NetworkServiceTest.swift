//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import XCTest
@testable import TTNewsApp

class NetworkServiceTest: XCTestCase {
    let networkService = NetworkService()
    func test_news_success() {
        let expectation = XCTestExpectation(description: "Load Currencies")
        networkService.news(by: 0, completion: { result, error in
            XCTAssertNil(error)
            XCTAssertNotNil(result)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

}
