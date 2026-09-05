import Foundation

/// The lifecycle of a single serial session, one state machine per tab.
public enum SessionState: Sendable, Equatable {
    case disconnected
    case opening
    case connected
    case transferring
    case closing
    case failed(String)
}
