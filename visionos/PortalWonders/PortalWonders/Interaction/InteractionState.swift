import Foundation
import simd

/// Thread-safe mailbox between ARKit hand updates (background task) and `CreatureSystem`.
final class InteractionState: @unchecked Sendable {
    static let shared = InteractionState()

    private let lock = NSLock()
    private var hands: [String: (position: SIMD3<Float>, stamp: TimeInterval)] = [:]
    /// Samples older than this are treated as "hand lost".
    private let staleAfter: TimeInterval = 0.4

    func update(hand id: String, position: SIMD3<Float>) {
        lock.withLock { hands[id] = (position, Date.timeIntervalSinceReferenceDate) }
    }

    func clear() {
        lock.withLock { hands.removeAll() }
    }

    func handPositions() -> [SIMD3<Float>] {
        let now = Date.timeIntervalSinceReferenceDate
        return lock.withLock {
            hands.values.compactMap { now - $0.stamp < staleAfter ? $0.position : nil }
        }
    }
}
