import Foundation
import simd

/// Thread-safe mailbox between ARKit updates (background tasks) and `CreatureSystem`.
final class InteractionState: @unchecked Sendable {
    static let shared = InteractionState()

    private let lock = NSLock()
    private var hands: [String: (position: SIMD3<Float>, stamp: TimeInterval)] = [:]
    private var head: (position: SIMD3<Float>, forward: SIMD3<Float>, stamp: TimeInterval)?
    /// Samples older than this are treated as lost.
    private let staleAfter: TimeInterval = 0.4

    /// Where the wearer's head is assumed to be before tracking reports anything.
    static let defaultHead: SIMD3<Float> = [0, 1.5, 0]

    func update(hand id: String, position: SIMD3<Float>) {
        lock.withLock { hands[id] = (position, Date.timeIntervalSinceReferenceDate) }
    }

    func updateHead(position: SIMD3<Float>, forward: SIMD3<Float>) {
        lock.withLock { head = (position, forward, Date.timeIntervalSinceReferenceDate) }
    }

    func clear() {
        lock.withLock { hands.removeAll(); head = nil }
    }

    func handPositions() -> [SIMD3<Float>] {
        let now = Date.timeIntervalSinceReferenceDate
        return lock.withLock {
            hands.values.compactMap { now - $0.stamp < staleAfter ? $0.position : nil }
        }
    }

    /// Head position and gaze direction; falls back to a seated default at the origin.
    func headPose() -> (position: SIMD3<Float>, forward: SIMD3<Float>) {
        let now = Date.timeIntervalSinceReferenceDate
        return lock.withLock {
            if let head, now - head.stamp < 1.0 { return (head.position, head.forward) }
            return (Self.defaultHead, [0, 0, -1])
        }
    }
}
