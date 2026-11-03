import ARKit
import Observation
import QuartzCore
import simd

/// Streams the user's head pose and index-fingertip positions into `InteractionState` so
/// creatures can look at the wearer, keep a polite distance from their face, be summoned by a
/// reaching hand, and react to a touch. Requires `NSHandsTrackingUsageDescription` and
/// `NSWorldSensingUsageDescription` (both in project.yml).
@Observable
@MainActor
final class UserTracker {
    private let session = ARKitSession()
    private let hands = HandTrackingProvider()
    private let world = WorldTrackingProvider()
    private var handTask: Task<Void, Never>?
    private var headTask: Task<Void, Never>?

    private(set) var isRunning = false
    private(set) var lastError: String?

    func start(trackHands: Bool) async {
        guard !isRunning else { return }
        var providers: [any DataProvider] = []
        if WorldTrackingProvider.isSupported { providers.append(world) }
        if trackHands {
            if HandTrackingProvider.isSupported {
                providers.append(hands)
            } else {
                lastError = "Hand tracking is not available here (simulator?). Tap instead."
            }
        }
        guard !providers.isEmpty else { return }
        do {
            try await session.run(providers)
        } catch {
            lastError = "Tracking failed to start: \(error.localizedDescription)"
            return
        }
        isRunning = true

        if WorldTrackingProvider.isSupported {
            headTask = Task.detached { [world] in
                while !Task.isCancelled {
                    if let device = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), device.isTracked {
                        let m = device.originFromAnchorTransform
                        let position = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                        let forward = -SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z)
                        InteractionState.shared.updateHead(position: position, forward: forward)
                    }
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
        }

        if trackHands && HandTrackingProvider.isSupported {
            handTask = Task.detached { [hands] in
                for await update in hands.anchorUpdates {
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
    }

    func stop() {
        handTask?.cancel(); handTask = nil
        headTask?.cancel(); headTask = nil
        session.stop()
        InteractionState.shared.clear()
        isRunning = false
    }
}
