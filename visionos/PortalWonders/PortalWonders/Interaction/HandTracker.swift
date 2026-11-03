import ARKit
import Observation
import simd

/// Streams index-fingertip positions into `InteractionState` so creatures can look at, and be
/// summoned by, the user's hand. Requires `NSHandsTrackingUsageDescription` (see project.yml).
@Observable
@MainActor
final class HandTracker {
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private var streamTask: Task<Void, Never>?

    private(set) var isRunning = false
    private(set) var lastError: String?

    func start() async {
        guard !isRunning else { return }
        guard HandTrackingProvider.isSupported else {
            lastError = "Hand tracking is not supported on this device (simulator?)."
            return
        }
        do {
            try await session.run([provider])
        } catch {
            lastError = "Hand tracking failed to start: \(error.localizedDescription)"
            return
        }
        isRunning = true

        streamTask = Task.detached { [provider] in
            for await update in provider.anchorUpdates {
                let anchor = update.anchor
                let id = anchor.chirality == .left ? "left" : "right"
                guard update.event != .removed, anchor.isTracked,
                      let skeleton = anchor.handSkeleton else { continue }
                let tip = skeleton.joint(.indexFingerTip)
                guard tip.isTracked else { continue }
                let m = anchor.originFromAnchorTransform * tip.anchorFromJointTransform
                InteractionState.shared.update(hand: id,
                                               position: SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z))
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        session.stop()
        InteractionState.shared.clear()
        isRunning = false
    }
}
