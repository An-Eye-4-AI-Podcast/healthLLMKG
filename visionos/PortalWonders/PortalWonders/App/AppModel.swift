import SwiftUI
import Observation

/// App-wide state shared by the picker window and the immersive space.
@Observable
@MainActor
final class AppModel {
    enum ImmersiveState { case closed, inTransition, open }

    /// The world currently shown (or about to be shown) in the portal.
    var selectedEnvironment: WonderEnvironment = .trench
    var immersiveState: ImmersiveState = .closed

    /// Let creatures track the user's index finger (needs hand-tracking permission).
    var handTrackingEnabled = true
    /// Re-sample the video for image-based lighting every N seconds (0 = once at load).
    var lightingRefreshSeconds: Double = 20
    /// Audio on/off for the ambience bed.
    var ambienceEnabled = true
}
