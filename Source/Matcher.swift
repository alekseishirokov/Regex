// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation
import os.log

// MARK: - Matching

protocol Matching {
    /// Returns the next match in the input.
    func nextMatch() -> Regex.Match?
    /// Returns true if the most recent matching operation attempted to access additional input beyond the available input text.
    /// In this case, additional input text could turn the results to the Match.
    func hitEnd() -> Bool
}

// MARK: - BacktrackingMatcher

/// A [DFS-based (Backtracking) algorithm])(https://kean.github.io/post/regex-matcher#dfs-backtracking).
final class BacktrackingMatcher: Matching {
    private let regex: CompiledRegex
    private let transitions: ContiguousArray<ContiguousArray<CompiledTransition>>

    #if DEBUG
    private var symbols: Symbols { regex.symbols }
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    #endif

    // If `false`, some expensive pathes that calculate capture groups can be ignored
    private let isCapturingGroups: Bool
    private let isStartingFromStartIndex: Bool

    private var cursor: Cursor
    private var isFinished = false
    private var isHitEnd = false

    init(string: String, regex: CompiledRegex, options: Regex.Options, isMatchOnly: Bool) {
        self.regex = regex
        self.transitions = regex.fsm.transitions
        self.isCapturingGroups = !isMatchOnly && !regex.captureGroups.isEmpty
        self.isStartingFromStartIndex = regex.isFromStartOfString && !options.contains(.multiline)
        self.cursor = Cursor(string: string)
    }

    func nextMatch() -> Regex.Match? {
        guard !isFinished else {
            return nil
        }
        guard let match = findNextMatch() else {
            isFinished = true
            return nil
        }
        isFinished = !cursor.advance(toEndOfMatch: match) && !isStartingFromStartIndex
        return match
    }

    func hitEnd() -> Bool {
        return isHitEnd
    }

    private func findNextMatch() -> Regex.Match? {
        while true {
            if let match = firstMatchBacktracking(cursor, [:], 0) {
                return match
            }
            guard cursor.startIndex < cursor.endIndex, !isStartingFromStartIndex else {
                return nil
            }
            cursor.startAt(cursor.index(after: cursor.startIndex))
        }
    }

    /// - warning: The backtracking matcher hasn't been optimized much yet
    private func firstMatchBacktracking(_ cursor: Cursor, _ groupsStartIndexes: [CompiledState: String.Index], _ state: CompiledState) -> Regex.Match? {
        var cursor = cursor
        var groupsStartIndexes = groupsStartIndexes

        // Update capture groups
        if isCapturingGroups {
            if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
                // Capture a group
                let startIndex = groupsStartIndexes[captureGroup.start] {
                let groupIndex = captureGroup.index
                cursor.groups[groupIndex] = startIndex..<cursor.index
            } else {
                // Remember where the group started
                if regex.captureGroups.contains(where: { $0.start == state }) {
                    if groupsStartIndexes[state] == nil {
                        groupsStartIndexes[state] = cursor.index
                    }
                }
            }
        }

        #if DEBUG
        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(symbols.description(for: state))")
        #endif

        if transitions[state].isEmpty { // Found a match
            let match = Regex.Match(cursor, isCapturingGroups)
            #if DEBUG
            os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \(match)")
            #endif
            return match
        }

        var counter = 0
        for transition in transitions[state] {
            counter += 1

            #if DEBUG
            if transitions[state].count > 1 {
                os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] transition \(counter) / \(transitions[state].count)")
            }
            #endif

            var cursor = cursor

            switch transition.condition.canPerformTransition(cursor) {
            case .rejected:
                #if DEBUG
                os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor.index), \(cursor.character ?? "∅")] \("Failed")")
                #endif

                continue
            case let .accepted(count):
                if count > 0 {
                    cursor.advance(by: count) // Consume as many characters as need (zero for epsilon transitions)
                }
            }

            if let match = firstMatchBacktracking(cursor, groupsStartIndexes, transition.end) {
                return match
            }
        }

        return nil // No possible matches
    }
}

// MARK: - RegularMatcher (WARNING: Work in Progress)

/// A [BFS-based algorithm](https://kean.github.io/post/regex-matcher#bfs) which
/// guarantees linear complexity to the length of the input string, but doesn't
/// support features like backreferences or lazy quantifiers.
final class RegularMatcher: Matching {
    private let regex: CompiledRegex
    private let transitions: ContiguousArray<ContiguousArray<CompiledTransition>>

    #if DEBUG
    private var symbols: Symbols { regex.symbols }
    private let log: OSLog = Regex.isDebugModeEnabled ? OSLog(subsystem: "com.github.kean.matcher", category: "default") : .disabled
    #endif

    // If `false`, some expensive pathes that calculate capture groups can be ignored
    private let isCapturingGroups: Bool
    private let isStartingFromStartIndex: Bool
    private let isMatchOnly: Bool

    private var cursor: Cursor
    private var isFinished = false
    private var isHitEnd = false

    // Reuse allocated buffers across different invocations to avoid re-creating
    // them over and over again.
    private var reachableStates = SmallSet<CompiledState>(0)
    private var reachableUntil = [CompiledState: String.Index]() // [Optimization] Some transitions jump multiple indices at a time
    private var potentialMatch: Cursor?
    private var groupsStartIndexes = [CompiledState: String.Index]()
    private var stack = ContiguousArray<CompiledState>()
    private var encountered: ContiguousArray<Bool>
    private var deadEnds: ContiguousArray<String.Index?>

    /// - parameter isMatchOnly: If the user just wants to know if there is a match
    /// we can skip capturing groups, stop on the first match (no need to guarantee
    /// it's the longest one), etc.
    init(string: String, regex: CompiledRegex, options: Regex.Options, isMatchOnly: Bool) {
        self.regex = regex
        self.transitions = regex.fsm.transitions
        self.isMatchOnly = isMatchOnly
        self.isCapturingGroups = !isMatchOnly && !regex.captureGroups.isEmpty
        self.isStartingFromStartIndex = regex.isFromStartOfString && !options.contains(.multiline)
        self.cursor = Cursor(string: string)
        self.encountered = ContiguousArray(repeating: false, count: transitions.count)
        self.deadEnds = ContiguousArray(repeating: nil, count: transitions.count)
    }

    func nextMatch() -> Regex.Match? {
        guard !isFinished else {
            return nil
        }

        guard let match = findNextMatch() else {
            isFinished = true
            return nil
        }

        isFinished = !cursor.advance(toEndOfMatch: match) && !isStartingFromStartIndex

        return match
    }

    func hitEnd() -> Bool {
        return isHitEnd
    }

    private func findNextMatch() -> Regex.Match? {
        reachableStates = SmallSet(0)
        reachableUntil.removeAll()
        potentialMatch = nil
        if isCapturingGroups { groupsStartIndexes.removeAll() }

        while !reachableStates.isEmpty {
            findNextReachableStates()
        }

        if let cursor = potentialMatch { // Found a match
            let match = Regex.Match(cursor, isCapturingGroups)
            #if DEBUG
            os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Found match \(match)")
            #endif
            return match
        }

        #if DEBUG
        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Failed to find matches")
        #endif

        return nil
    }

    private func findNextReachableStates() {
        let newReachableStates = getNextReachableStates()

        guard !cursor.isEmpty else {
            reachableStates = SmallSet()
            return // The input string is empty, can stop now
        }

        reachableStates = newReachableStates

        #if DEBUG
        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: << Entering reachable states: \(reachableStates.map { symbols.description(for: $0) })")
        #endif

        if reachableStates.isEmpty && potentialMatch == nil {
            // Failed to find matches, restart from the initial state

            #if DEBUG
            os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Failed to find matches \(reachableStates.map { symbols.description(for: $0) })")
            #endif

            if isStartingFromStartIndex {
                cursor.startAt(cursor.endIndex)
                reachableStates = SmallSet()
            } else {
                cursor.startAt(cursor.index(after: cursor.startIndex))
                if isCapturingGroups { groupsStartIndexes.removeAll() }
                reachableStates = SmallSet(0)
            }
        } else {
            // Advance the cursor
            if reachableUntil.count > 0 && reachableUntil.count == reachableStates.count {
                // [Optimization] Jump multiple indices at a time without checking the condition again
                cursor.advance(to: reachableUntil.values.min()!)
                isHitEnd = cursor.isPastTheEnd
            } else {
                cursor.advance(by: 1)
                isHitEnd = cursor.isPastTheEnd
            }
        }
    }

    /// Uses breadth-first-search to find states reachable from the current
    /// reachable set of states after consuming the next character (or multiple
    /// characters at the same time in case of Match.string).
    ///
    /// As it enters states, it also captures groups, and collects potential matches.
    /// It doesn't stop on the first found match and tries to find the longest
    /// match instead (aka "greedy").
    private func getNextReachableStates() -> SmallSet<CompiledState> {
        var newReachableStates = SmallSet<CompiledState>()

        #if DEBUG
        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: >> Reachable \(reachableStates.map { symbols.description(for: $0) })")
        #endif

        for index in encountered.indices { encountered[index] = false }

        for state in reachableStates {
            // [Optimization] Support for Match.string
            if let index = reachableUntil[state] {
                if index > cursor.index {
                    newReachableStates.insert(state) // Don't check the condition again
                    encountered[state] = true
                    continue
                } else {
                    reachableUntil[state] = nil
                }
            }

            // Go throught the graph of states using breadth-first search (BFS).
            stack.append(state)
            while let state = stack.popLast() {
                guard !encountered[state] else { continue }
                encountered[state] = true

                // Capture a group if needed or update group start indexes
                if isCapturingGroups {
                    updateCaptureGroups(enteredState: state)
                }

                #if DEBUG
                 os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Check reachability from \(symbols.description(for: state)))")
                 #endif

                /// Reached the end state, remember the potential match. There might be multiple
                /// ways to reach the end state that's why it is not stopping on the first match.
                guard !transitions[state].isEmpty else { // End state
                    updatePotentialMatch(state)
                    if isMatchOnly { // [Optimization] Stop early, we don't need to guarantee the longest match
                        return SmallSet()
                    }
                    continue
                }

                for transition in transitions[state] {
                    if let deadEndIndex = deadEnds[transition.end], cursor.index < deadEndIndex {
                        #if DEBUG
                        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Reached dead end \(symbols.description(for: state)))")
                        #endif
                        continue // [Optimization] We reached a dead end
                    }

                    let result = transition.condition.canPerformTransition(cursor)
                    switch result {
                    case let .rejected(count):
                        // [Optimization] If we come accross this state later, we
                        // can quit search early – it never leads to a match
                        deadEnds[state] = cursor.index
                        if count > 0 {
                            cursor.advance(by: count)
                            isHitEnd = true
                        }
                    case let .accepted(count):
                        if count > 0 { // Consumed characters
                            newReachableStates.insert(transition.end)
                            // The state is going to be reachable until index T+count is reached
                            if count > 1 {
                                reachableUntil[transition.end] = cursor.index(cursor.index, offsetBy: count, isLimited: true)
                            }
                        } else {
                            stack.append(transition.end) // Espilon, continue walking the graph
                        }
                    }

                    #if DEBUG
                    logTransition(transition, result)
                    #endif
                }
            }
        }

        return newReachableStates
    }

    /// Update capture groups and also group start indexes on entering the given state.
    private func updateCaptureGroups(enteredState state: CompiledState) {
        if let captureGroup = regex.captureGroups.first(where: { $0.end == state }),
            // Capture a group
            let startIndex = groupsStartIndexes[captureGroup.start] {
            let groupIndex = captureGroup.index
            cursor.groups[groupIndex] = startIndex..<cursor.index
        } else {
            // Remember where the group started
            if regex.captureGroups.contains(where: { $0.start == state }) {
                if groupsStartIndexes[state] == nil {
                    groupsStartIndexes[state] = cursor.index
                }
            }
        }
    }

    private func updatePotentialMatch(_ state: CompiledState) {
        potentialMatch = cursor // Found a match!

        #if DEBUG
        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: Found a potential match \(symbols.description(for: state))")
        #endif
    }

    // MARK: Logging

    #if DEBUG
    private func logTransition(_ transition: CompiledTransition, _ result: ConditionResult) {
        let message: String
        switch result {
        case .rejected: message = "State NOT reachable"
        case let .accepted(count): message = "State reachable consuming \(count)"
        }
        os_log(.default, log: log, "%{PUBLIC}@", "– [\(cursor)]: \(message) \(symbols.description(for: transition.end))")
    }
    #endif
}
