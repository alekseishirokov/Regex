// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import XCTest
import Regex

/// Regex examples from https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions
class RegexSpecTests: XCTestCase {

    // MARK: Character Classes

    // TODO: implement Unicode categories support
    func testCharacterClasses1() throws {
        let pattern = #"gr[ae]y\s\S+?[\s\p{P}]"#
        let string = "The gray wolf jumped over the grey wall."

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["gray wolf ", "grey wall."])
    }

    func testCharacterClasses2() throws {
        let pattern = #"\b[A-Z]\w*\b"#
        let string = "A city Albany Zulu maritime Marseilles"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["A", "Albany", "Zulu", "Marseilles"])
    }

    func testCharacterClasses3() throws {
        let pattern = #"\bth[^o]\w+\b"#
        let string = "thought thing though them through thus thorough this"

        let regex = try Regex(pattern)
        let matches = regex.matches(in: string).map { $0.value }

        XCTAssertEqual(matches, ["thing", "them", "through", "thus", "this"])
    }
}
