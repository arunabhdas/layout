//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class EnumExpressionTests: XCTestCase {
    func testContentModeLiteral() {
        let node = LayoutNode(
            expressions: [
                "contentMode": "center",
            ]
        )
        let expected = UIViewContentMode.center
        XCTAssertEqual(try node.value(forSymbol: "contentMode") as? UIViewContentMode, expected)
    }

    func testContentModeConstant() {
        let expected = UIViewContentMode.center
        let node = LayoutNode(
            constants: [
                "mode": expected,
            ],
            expressions: [
                "contentMode": "mode",
            ]
        )
        XCTAssertEqual(try node.value(forSymbol: "contentMode") as? UIViewContentMode, expected)
    }

    func testReturnKeyLiteral() {
        let node = LayoutNode(
            view: UITextField(),
            expressions: [
                "returnKeyType": "go",
            ]
        )
        let expected = UIReturnKeyType.go
        XCTAssertEqual(try node.value(forSymbol: "returnKeyType") as? UIReturnKeyType, expected)
    }

    func testReturnKeyConstant() {
        let expected = UIReturnKeyType.go
        let node = LayoutNode(
            view: UITextField(),
            constants: [
                "type": expected,
            ],
            expressions: [
                "returnKeyType": "type",
            ]
        )
        XCTAssertEqual(try node.value(forSymbol: "returnKeyType") as? UIReturnKeyType, expected)
    }
}
