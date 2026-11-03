import RealityKit
import simd

/// Per-creature state driven by `CreatureSystem`. Lives on the creature's root entity.
struct CreatureComponent: Component {
    enum Phase { case idle, approaching, visiting, retreating }

    var spec: CreatureSpec
    var phase: Phase = .idle
    var phaseElapsed: Double = 0
    var phaseDuration: Double
    /// Free-running clock for bobbing; randomised so creatures do not move in lockstep.
    var time: Double = Double.random(in: 0..<10)

    /// Room-space Z of the portal plane and the portal's centre.
    var portalPlaneZ: Float
    var portalCenter: SIMD3<Float>
    /// Distance from the root to the tip of the nose along +Z (after scaling).
    var noseOffset: Float

    var currentYaw: Float = 0
    var reactionRequested = false
    var reactionElapsed: Double? = nil
    var summonRequested = false

    var hasReactionClip = false
    /// Set by the phase machine on the frame a new phase begins; consumed by the voice logic.
    var enteredPhase = false
}
