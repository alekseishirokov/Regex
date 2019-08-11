// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

// MARK: - State

enum Capturing {
    case none
    case start
    case end
}

/// Represents a state of the finite state machine.
final class State: Hashable, CustomStringConvertible {
    unowned var capturingEndState: State?

    var isEnd: Bool {
        return transitions.isEmpty
    }
    var transitions = [Transition]()

    init(_ description: String) {
        self.description = description
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (lhs: State, rhs: State) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    // MARK: CustomStringConvertible

    let description: String
}

// MARK: - Transition

/// A transition between two states of the state machine.
struct Transition: CustomStringConvertible {
    /// A state into which the transition is performed.
    let toState: State

    /// If true, transition doesn't consume a character when performed.
    let isEpsilon: Bool

    /// Determines whether the transition is possible in the given context.
    let condition: (Cursor, Context) -> Bool

    /// Adds a chance for transition to update update current state.
    let perform: (Cursor, Context) -> (Context)

    // MARK: Factory

    /// Creates a transition which consumes a character.
    static func consuming(_ toState: State, _ match: @escaping (Character) -> Bool) -> Transition {
        return Transition(
            toState: toState,
            isEpsilon: false,
            condition: { cursor, _ in
                guard let character = cursor.character else {
                    return false
                }
                return match(character)
            }, perform: { _, context in context }
        )
    }

    /// Creates a transition which doesn't consume characters.
    /// - parameter perform: A closure to be performed every time a
    /// transition is performed. Allows you to map state (context). By default
    /// returns context without modification.
    static func epsilon(_ toState: State,
                        perform: @escaping (Cursor, Context) -> Context = { _, context in context },
                        _ condition: @escaping (Cursor, Context) -> Bool = { _, _ in true }) -> Transition {
        return Transition(toState: toState, isEpsilon: true, condition: condition, perform: perform)
    }

    // MARK: CustomStringConvertible

    var description: String {
        return "\(isEpsilon ? "Epsilon" : "Transition") to \(toState)"
    }
}

/// Execution context which is passed from state to state when transitions are
/// performed. The context is copied throughout the execution making the execution
/// functional/stateless.
/// - warning: Avoid using reference types in context!
typealias Context = [AnyHashable: AnyHashable]