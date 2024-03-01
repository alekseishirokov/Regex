//
//  HitEndTests.swift
//  RegexTests
//
//  Created by Alex Shirokov on 27.02.2024.
//  Copyright © 2024 kean. All rights reserved.
//

import XCTest
import Regex

final class HitEndTests: XCTestCase {

    func testByDefaultReturnsFalse() throws {
        let pattern = "doesnotmatter"
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenInputIsPrefixOfPatternReturnsTrue() throws {
        let pattern = #"aa"#
        let string = "a"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenInputIsNotPrefixOfPatternReturnsFalse() throws {
        let pattern = "aa"
        let string = "b"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternIsARangeAndContainsInputReturnsTrue() throws {
        let pattern = #"[A-Z]"#
        let string = "F"

        let regex = try Regex(pattern)

        XCTAssertTrue(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsARangeAndNotContainsInputReturnsFalse() throws {
        let pattern = #"[A-Z]"#
        let string = "@"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternHasQuantorsAndInputIsPrefixOfPatternReturnsTrue() throws {
        let pattern = #"a{2}"#
        let string = "a"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternHasQuantorsAndInputIsNotPrefixOfPatternReturnsFalse() throws {
        let pattern = #"a{2}"#
        let string = "b"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsAPrefixOfPatternReturnsTrue() throws {
        let pattern = #"^([A-Z][0-9]{3}[A-Z]{2,3})|([0-9]{3}[A-Z]{2,3}[0-9]{2})$"#
        let string = "A22"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsAPrefixOfPatternReturnsTrue2() throws {
        let pattern = #"^([A-Z][0-9]{3}[A-Z]{2,3})$"#
        let string = "A22"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsAPrefixOfPatternReturnsTrue3() throws {
        let pattern = #"^[A-Z][0-9]{3}[A-Z]{2,3}"#
        let string = "A22"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsAPrefixOfPatternReturnsTrue4() throws {
        let pattern = #"[A-Z][0-9]{3}"#
        let string = "A22"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsAPrefixOfPatternReturnsTrue5() throws {
        let pattern = #"^[A-Z][0-9]{3}"#
        let string = "A22"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsPartialReturnsTrue() throws {
        let pattern = #"^([A-Z][0-9]{3}[A-Z]{2,3})|([0-9]{3}[A-Z]{2,3}[0-9]{2})$"#
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch("A"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("A0"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("A00"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("A000"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("A000A"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("0"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("00"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("000"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("000A"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("000AA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("000AA0"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("000AAA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("000AAA0"))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsAVehicleReturnsTrue() throws {
        let pattern = #"^([A-Z][0-9]{3}[A-Z]{2,3})|([0-9]{3}[A-Z]{2,3}[0-9]{2})$"#
        let regex = try Regex(pattern)

        XCTAssertTrue(regex.isMatch("A000AA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertTrue(regex.isMatch("A000AAA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertTrue(regex.isMatch("000AA00"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertTrue(regex.isMatch("000AAA00"))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsVehicleAndInputIsNotAPrefixOfPatternReturnsFalse() throws {
        let pattern = #"^([A-Z][0-9]{3}[A-Z]{2,3})|([0-9]{3}[A-Z]{2,3}[0-9]{2})$"#
        let string = "&"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternHasBeginStringSignAndInputIsNotPrefixOfPatternReturnsFalse() throws {
        let pattern = #"^([A-Z][0-9]{3}[A-Z]{2,3})"#
        let string = "&"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternHasBeginStringSignAndInputIsNotPrefixOfPatternReturnsFalse2() throws {
        let pattern = #"^[A-Z]"#
        let string = "&"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternHasBeginStringSignAndInputIsNotPrefixOfPatternReturnsFalse3() throws {
        let pattern = #"^A"#
        let string = "&"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternHasBeginStringSignAndInputIsPrefixOfPatternReturnsTrue() throws {
        let pattern = #"^AA"#
        let string = "A"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsComplexAndInputIsNotPrefixOfPatternReturnsFalse() throws {
        let pattern = #"([A-Z][0-9]{3}[A-Z]{2,3})"#
        let string = "&"

        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternHasRangeWithQuantityAndInputIsAPrefixOfPatternReturnsTrue() throws {
        let pattern = #"[a-z]{3}"#
        let string = "a"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternHasRangeWithQuantityAndInputIsNotAPrefixOfPatternReturnsTrue() throws {
        let pattern = #"[a-z]{3}"#
        let string = "b"

        Regex.isDebugModeEnabled = true
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch(string))
        XCTAssertTrue(regex.hitEnd())
    }

    func testWhenPatternIsForeignVehicleAndInputIsAVehicleReturnsTrue() throws {
        let pattern = #"^\S{3,5}$"#
        let regex = try Regex(pattern)

        XCTAssertTrue(regex.isMatch("AAA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertTrue(regex.isMatch("AAAA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertTrue(regex.isMatch("AAAAA"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("AAAAAB"))
        XCTAssertFalse(regex.hitEnd())
    }

    func testWhenPatternIsForeignVehicleAndInputIsAPrefixReturnsTrue() throws {
        let pattern = #"^\S{3,5}$"#
        let regex = try Regex(pattern)

        XCTAssertFalse(regex.isMatch("A"))
        XCTAssertTrue(regex.hitEnd())
        XCTAssertFalse(regex.isMatch("AA"))
        XCTAssertTrue(regex.hitEnd())
    }

}
