import Foundation

/// Discrete emotional states the robot can be in. Drives all animation.
enum MardiMood: Equatable, Sendable {
    case idle
    case summoned
    case listening
    case thinking
    case success
    case error
    case selectMode
    case sleeping
}
