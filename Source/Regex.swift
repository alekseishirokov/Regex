// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Regex

/// Represens a regular expression.
///
/// Usage:
///
/// ```
/// let regex = try Regex(#"<\/?[\w\s]*>|<.+[\W]>"#)
/// for match in regex.matches(in: "<h1>Title</h1>\n<p>Text</p>") {
///     print(match.value)
///     // Prints ["<h1>", "</h1>", "<p>", "</p>"]
/// }
/// ```
///
/// `Regex` is immutable and thread-safe, a single instance can be used in
/// matching operations on multiple threads at once.
public final class Regex {
    private let options: Options
    private let regex: CompiledRegex
    private var isHitEnd = false

    #if DEBUG
    private let log: OSLog = Regex.isDebugModeEnabled ?
        OSLog(subsystem: "com.github.kean.regex", category: "default") :
        .disabled
    #endif

    /// Returns the number of capture groups in the regular expression.
    public var numberOfCaptureGroups: Int {
        regex.captureGroups.count
    }

    /// Enable debug mode to enable logging. Disabled by default.
    public static var isDebugModeEnabled = false

    /// Initializes the regex with the given pattern.
    /// - options: Options are empty by default, see `Regex.Options` to learn more.
    public init(_ pattern: String, _ options: Options = []) throws {
        do {
            let ast = try Regex.parse(pattern)
            let optimizedAst = Optimizer().optimize(ast)
            self.regex = try Compiler(optimizedAst, options).compile()
            self.options = options

            #if DEBUG
            os_log(.default, log: self.log, "AST: \n%{PUBLIC}@", ast.description)
            os_log(.default, log: self.log, "AST (Optimized): \n%{PUBLIC}@", optimizedAst.description)
            os_log(.default, log: self.log, "Expression: \n%{PUBLIC}@", regex.symbols.description(for: 0))
            #endif
        } catch {
            var error = error as! Error
            error.pattern = pattern // Attach additional context
            throw error
        }
    }

    private static func parse(_ pattern: String) throws -> AST {
        do {
            let parser = Parsers.regex
            guard let ast = try parser.parse(pattern) else {
                throw ParserError("Unexpected error")
            }
            return ast
        } catch {
            // TODO: attach an index where error occured
            throw Regex.Error((error as! ParserError).message, 0)
        }
    }
}

// MARK: - Regex (Match)

public extension Regex {
    /// Determine whether the regular expression pattern occurs in the input text.
    func isMatch(_ string: String) -> Bool {
        let matcher = makeMatcher(for: string, isMatchOnly: true)
        let match = matcher.nextMatch()
        isHitEnd = matcher.hitEnd()
        return match != nil
    }

    /// Returns first match in the given string.
    func firstMatch(in string: String) -> Match? {
        let matcher = makeMatcher(for: string)
        let match = matcher.nextMatch()
        isHitEnd = matcher.hitEnd()
        return match
    }

    /// Returns an array containing all the matches in the string.
    func matches(in string: String) -> [Match] {
        let matcher = makeMatcher(for: string)
        var matches = [Match]()
        while let match = matcher.nextMatch() {
            matches.append(match)
        }
        isHitEnd = matcher.hitEnd()
        return matches
    }

    func hitEnd() -> Bool {
        return isHitEnd
    }

    /// - paramter isMatchOnly: enables some performance optimizations
    private func makeMatcher(for string: String, isMatchOnly: Bool = false) -> Matching {
        #if DEBUG
        os_log(.default, log: log, "%{PUBLIC}@", "Use \(regex.isRegular ? "regular" : "backtracking") matcher")
        #endif

        if regex.isRegular {
            return RegularMatcher(string: string, regex: regex, options: options, isMatchOnly: isMatchOnly)
        } else {
            return BacktrackingMatcher(string: string, regex: regex, options: options, isMatchOnly: isMatchOnly)
        }
    }
}

// MARK: - Regex.Options

public extension Regex {
    /// Define the regular expression options.
    struct Options: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Match letters in the pattern independent of case.
        public static let caseInsensitive = Options(rawValue: 1 << 0) // 'i'

        /// Control the behavior of "^" and "$" in a pattern. By default these
        /// will only match at the start and end, respectively, of the input text.
        /// If this flag is set, "^" and "$" will also match at the start and end
        /// of each line within the input text.
        public static let multiline = Options(rawValue: 1 << 1) // 'm'

        /// Allow `.` to match any character, including line separators.
        public static let dotMatchesLineSeparators = Options(rawValue: 1 << 2) // 's'
    }
}

// MARK: - Regex.Match

public extension Regex {
    struct Match {
        /// A full match.
        ///
        /// Substrings are only intended for short-term storage because they keep
        /// a reference to the original String. When the match is complete and you
        /// want to store the results or pass them on to another subsystem,
        /// you should create a new String from a match substring.
        public let fullMatch: Substring

        public let groups: [Substring]

        /// Index where the search ended.
        let endIndex: String.Index

        init(_ cursor: Cursor, _ hasCaptureGroups: Bool) {
            self.fullMatch = cursor[cursor.startIndex..<cursor.index]
            if hasCaptureGroups {
                self.groups = cursor.groups
                    .sorted(by: { $0.key < $1.key }) // Sort by the index of the group
                    .map { cursor[$0.value] }
            } else {
                self.groups = []
            }
            self.endIndex = cursor.index
        }
    }
}

// MARK: - Regex.Error

extension Regex {
    public struct Error: Swift.Error, LocalizedError {
        public let message: String
        public let index: Int
        public var pattern: String = ""

        init(_ message: String, _ index: Int) {
            self.message = message
            self.index = index
        }

        public var errorDescription: String? {
            return "\(message) in pattern: \(patternWithHighlightedError)"
        }

        public var patternWithHighlightedError: String {
            let i = pattern.index(pattern.startIndex, offsetBy: index)
            var s = pattern
            guard s.indices.contains(i) else {
                return ""
            }
            s.replaceSubrange(i...i, with: "\(s[i])💥")
            return s
        }
    }
}
