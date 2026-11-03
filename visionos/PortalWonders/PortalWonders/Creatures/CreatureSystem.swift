import RealityKit
import simd
import Foundation

/// Moves every creature through idle → approach → visit → retreat, turns it toward the user's
/// hand, plays reactions, and drives the video/neutral lighting blend as it protrudes.
final class CreatureSystem: System {
    private static let query = EntityQuery(where: .has(CreatureComponent.self))
    private static let rippleQuery = EntityQuery(where: .has(PortalRippleComponent.self))

    /// Closest a creature's nose may come to the wearer's face, in metres.
    private let personalSpace: Float = 0.55
    /// A fingertip this close to the snout counts as a touch.
    private let touchRadius: Float = 0.22

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard dt > 0 else { return }
        let hands = InteractionState.shared.handPositions()
        let head = InteractionState.shared.headPose()
        let ripple = Array(context.entities(matching: Self.rippleQuery, updatingSystemWhen: .rendering)).first

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var c = entity.components[CreatureComponent.self] else { continue }
            c.time += Double(dt)
            c.phaseElapsed += Double(dt)

            let nearestHand = hands.min { simd_distance($0, c.portalCenter) < simd_distance($1, c.portalCenter) }
            let handIsNear = nearestHand.map { simd_distance($0, c.portalCenter) < 1.1 } ?? false

            c.enteredPhase = false
            advancePhase(&c, handIsNear: handIsNear)
            if c.enteredPhase && c.phase == .visiting { speak(entity, &c, .arrive) }
            if c.phase == .idle { idleChatter(entity, &c) }

            // --- position -------------------------------------------------------------
            let t = Float(c.time)
            let progress = Float(min(c.phaseElapsed / max(c.phaseDuration, 0.001), 1))
            let eased = smoothstep(progress)
            let home = c.spec.homePosition
            // The visit spot slides sideways with the wearer so the creature comes to *you*.
            var visit = c.spec.visitPosition
            visit.x += clamp(head.position.x, -0.8, 0.8) * 0.5
            var position: SIMD3<Float>
            switch c.phase {
            case .idle:        position = home + wander(c.spec.locomotion, t)
            case .approaching: position = simd_mix(home, visit, SIMD3(repeating: eased)) + travelFlourish(c.spec.locomotion, progress)
            case .visiting:    position = visit + visitBob(c.spec.locomotion, t)
            case .retreating:  position = simd_mix(visit, home, SIMD3(repeating: eased)) + travelFlourish(c.spec.locomotion, 1 - progress)
            }

            // --- heading --------------------------------------------------------------
            var desiredYaw: Float
            switch c.phase {
            case .approaching:
                let dir = visit - home
                desiredYaw = atan2(dir.x, dir.z)
            case .retreating:
                let dir = home - visit
                desiredYaw = atan2(dir.x, dir.z)
            case .visiting:
                // Face the wearer's head; a nearby hand steals the attention.
                let focus = (handIsNear ? nearestHand : nil) ?? head.position
                let dir = focus - position
                desiredYaw = clamp(atan2(dir.x, dir.z), -1.0, 1.0)
            case .idle:
                switch c.spec.locomotion {
                case .swim:  desiredYaw = .pi / 2 + sin(t * 0.3) * 0.8
                case .graze: desiredYaw = sin(t * 0.2) * 1.0
                case .bound: desiredYaw = 0
                }
            }
            c.currentYaw += shortestAngle(desiredYaw - c.currentYaw) * min(1, dt * 3)

            var pitch: Float = 0
            var roll: Float = 0
            if c.spec.locomotion == .swim {
                roll = sin(t * 1.3) * 0.05
                if c.phase == .approaching { pitch = -0.15 * sin(progress * .pi) }
            }

            // --- reactions ------------------------------------------------------------
            if c.reactionRequested {
                c.reactionRequested = false
                c.reactionElapsed = 0
                setReactionFX(entity, enabled: true)
                speak(entity, &c, .react)
                if c.hasReactionClip, let model = entity.children.first,
                   let clip = animation(named: c.spec.reactionAnimationName, in: model) {
                    model.playAnimation(clip, transitionDuration: 0.15, startsPaused: false)
                }
            }
            if var r = c.reactionElapsed {
                r += Double(dt)
                let rf = Float(r)
                if !c.hasReactionClip {
                    switch c.spec.locomotion {
                    case .swim:  roll += min(rf / 1.0, 1) * 2 * .pi                      // barrel roll
                    case .graze: pitch -= sin(min(rf / 1.2, 1) * .pi) * 0.55               // rear up
                    case .bound: position.y += sin(min(rf / 0.6, 1) * .pi) * 0.25          // hop
                    }
                }
                if r > 1.6 {
                    c.reactionElapsed = nil
                    setReactionFX(entity, enabled: false)
                } else {
                    c.reactionElapsed = r
                }
            }

            // --- personal space ---------------------------------------------------------
            // Never push the nose closer than `personalSpace` to the wearer's face.
            let maxZ = head.position.z - personalSpace - c.noseOffset
            if position.z > maxZ { position.z = maxZ }

            // --- touch --------------------------------------------------------------------
            let orientation = simd_quatf(angle: c.currentYaw, axis: [0, 1, 0])
            let snout = position + orientation.act(c.touchLocal)
            if c.reactionElapsed == nil,
               hands.contains(where: { simd_distance($0, snout) < touchRadius }) {
                c.reactionRequested = true          // a boop on the nose
            }

            // --- apply ----------------------------------------------------------------
            entity.position = position
            entity.orientation = simd_quatf(angle: c.currentYaw, axis: [0, 1, 0])
                * simd_quatf(angle: pitch, axis: [1, 0, 0])
                * simd_quatf(angle: roll, axis: [0, 0, 1])

            animateSecondaryParts(entity, c, t: t, handIsNear: handIsNear)
            updateLightingBlend(entity, position: position, c, dt: dt)
            updateTrail(entity, c)
            updateCrossing(entity, &c, position: position, ripple: ripple)

            entity.components[CreatureComponent.self] = c
        }
    }

    // MARK: Phase machine

    private func advancePhase(_ c: inout CreatureComponent, handIsNear: Bool) {
        func enter(_ phase: CreatureComponent.Phase, _ seconds: Double) {
            c.phase = phase
            c.phaseElapsed = 0
            c.phaseDuration = seconds
            c.enteredPhase = true
        }
        switch c.phase {
        case .idle:
            if c.summonRequested || handIsNear || c.phaseElapsed >= c.phaseDuration {
                c.summonRequested = false
                enter(.approaching, c.spec.approachSeconds)
            }
        case .approaching:
            if c.phaseElapsed >= c.phaseDuration { enter(.visiting, c.spec.visitSeconds) }
        case .visiting:
            // Linger as long as a hand is nearby — puppies especially.
            if c.phaseElapsed >= c.phaseDuration && !handIsNear { enter(.retreating, c.spec.retreatSeconds) }
        case .retreating:
            if c.phaseElapsed >= c.phaseDuration { enter(.idle, c.spec.idleSeconds + Double.random(in: 0...3)) }
        }
    }

    // MARK: Motion flavour

    private func wander(_ locomotion: CreatureLocomotion, _ t: Float) -> SIMD3<Float> {
        switch locomotion {
        case .swim:  return [sin(t * 0.45) * 0.35, sin(t * 0.8) * 0.12, cos(t * 0.3) * 0.25]
        case .graze: return [sin(t * 0.15) * 0.5, 0, cos(t * 0.12) * 0.3]
        case .bound: return [sin(t * 4) * 0.02, abs(sin(t * 2.5)) * 0.03, 0]
        }
    }

    private func travelFlourish(_ locomotion: CreatureLocomotion, _ progress: Float) -> SIMD3<Float> {
        switch locomotion {
        case .swim:  return [0, sin(progress * .pi) * 0.25, 0]              // one lazy swoop
        case .graze: return [0, abs(sin(progress * .pi * 6)) * 0.03, 0]     // footfalls
        case .bound: return [0, abs(sin(progress * .pi * 3)) * 0.18, 0]     // three bounds
        }
    }

    private func visitBob(_ locomotion: CreatureLocomotion, _ t: Float) -> SIMD3<Float> {
        switch locomotion {
        case .swim:  return [0, sin(t * 1.3) * 0.04, 0]
        case .graze: return [0, sin(t * 0.9) * 0.01, 0]
        case .bound: return [0, abs(sin(t * 6)) * 0.015, 0]
        }
    }

    /// Wags a "tail" pivot and nods a "head" pivot if the model exposes them (placeholders do).
    private func animateSecondaryParts(_ entity: Entity, _ c: CreatureComponent, t: Float, handIsNear: Bool) {
        if let tail = entity.findEntity(named: "tail") {
            let excited = c.phase == .visiting || handIsNear
            let rate: Float = c.spec.locomotion == .bound ? (excited ? 14 : 4) : 2
            let amp: Float = c.spec.locomotion == .bound ? 0.45 : 0.25
            tail.orientation = simd_quatf(angle: sin(t * rate) * amp, axis: [0, 1, 0])
        }
        if let head = entity.findEntity(named: "head") {
            let nod: Float = handIsNear ? sin(t * 2.2) * 0.12 : sin(t * 0.7) * 0.04
            head.orientation = simd_quatf(angle: nod, axis: [1, 0, 0])
        }
        // Legs trot (diagonal pairs in phase) while travelling, settle when parked.
        let travelling = c.phase == .approaching || c.phase == .retreating
        let gaitRate: Float = c.spec.locomotion == .bound ? 11 : 6
        let gaitAmp: Float = travelling ? (c.spec.locomotion == .bound ? 0.6 : 0.4) : 0.03
        for (name, phase) in [("legFL", Float(0)), ("legBR", 0), ("legFR", .pi), ("legBL", .pi)] {
            if let leg = entity.findEntity(named: name) {
                leg.orientation = simd_quatf(angle: sin(t * gaitRate + phase) * gaitAmp, axis: [1, 0, 0])
            }
        }
    }

    private func setReactionFX(_ entity: Entity, enabled: Bool) {
        guard let fx = entity.findEntity(named: "reactionFX") else { return }
        fx.isEnabled = enabled
        if var emitter = fx.components[ParticleEmitterComponent.self] {
            emitter.isEmitting = enabled
            fx.components.set(emitter)
        }
    }

    // MARK: Voice

    private enum Occasion { case arrive, react, idle }

    /// Plays a random clip for the occasion from the creature's body, honouring the cooldown.
    private func speak(_ entity: Entity, _ c: inout CreatureComponent, _ occasion: Occasion) {
        guard var voice = entity.components[VoiceComponent.self] else { return }
        guard c.time - voice.lastCallAt >= voice.cooldown else { return }
        let pool: [AudioFileResource]
        let gain: Double
        switch occasion {
        case .arrive: pool = voice.arrive; gain = 0
        case .react:  pool = voice.react;  gain = 2
        case .idle:   pool = voice.idle;   gain = voice.idleGain   // distant, inside the world
        }
        guard let clip = pool.randomElement() else { return }
        let controller = entity.playAudio(clip)
        controller.gain = gain
        voice.lastCallAt = c.time
        entity.components.set(voice)
    }

    /// Idle creatures call out now and then so the world sounds inhabited.
    private func idleChatter(_ entity: Entity, _ c: inout CreatureComponent) {
        guard var voice = entity.components[VoiceComponent.self], c.time >= voice.nextIdleCallAt else { return }
        voice.nextIdleCallAt = c.time + Double.random(in: voice.idleEvery)
        entity.components.set(voice)
        speak(entity, &c, .idle)
    }

    // MARK: Effects

    /// Bubble trails only run while the creature is actually swimming somewhere.
    private func updateTrail(_ entity: Entity, _ c: CreatureComponent) {
        guard let trail = entity.findEntity(named: "trail"),
              let tag = trail.components[TrailComponent.self], tag.onlyWhileMoving,
              var emitter = trail.components[ParticleEmitterComponent.self] else { return }
        let shouldEmit = c.phase == .approaching || c.phase == .retreating
        if emitter.isEmitting != shouldEmit {
            emitter.isEmitting = shouldEmit
            trail.components.set(emitter)
        }
    }

    /// Fires the portal ripple at the point where the nose breaks the plane.
    private func updateCrossing(_ entity: Entity, _ c: inout CreatureComponent,
                                position: SIMD3<Float>, ripple: Entity?) {
        let outside = (position.z + c.noseOffset) > c.portalPlaneZ
        defer { c.wasOutside = outside }
        guard outside != c.wasOutside, c.spec.crossesPortal, let ripple else { return }
        ripple.setPosition([position.x, position.y + c.touchLocal.y, c.portalPlaneZ + 0.02], relativeTo: nil)
        if var emitter = ripple.components[ParticleEmitterComponent.self] {
            emitter.burst()
            ripple.components.set(emitter)
        }
    }

    // MARK: Lighting hand-off

    /// Protruding geometry is drawn in the room by the main pass (real-world lighting); the rest
    /// stays video-lit inside the world. We also cross-fade the creature's own probe toward the
    /// neutral room probe so the seam at the plane reads as one object, not two.
    private func updateLightingBlend(_ entity: Entity, position: SIMD3<Float>, _ c: CreatureComponent, dt: Float) {
        guard var lb = entity.components[LightBlendComponent.self] else { return }
        let protrusion = (position.z + c.noseOffset) - c.portalPlaneZ   // > 0 when the nose is in the room
        let target = clamp(protrusion / 0.8, 0, 1)
        let blend = lb.blend + (target - lb.blend) * min(1, dt * 4)
        guard abs(blend - lb.blend) > 0.002 else { return }
        lb.blend = blend
        entity.components.set(lb)
        entity.components.set(ImageBasedLightComponent(source: .blend(lb.video, lb.neutral, blend),
                                                       intensityExponent: lb.intensityExponent))
    }

    // MARK: Math

    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(x, lo), hi)
    }

    private func smoothstep(_ x: Float) -> Float {
        let c = clamp(x, 0, 1)
        return c * c * (3 - 2 * c)
    }

    private func shortestAngle(_ a: Float) -> Float {
        var x = fmod(a + .pi, 2 * .pi)
        if x < 0 { x += 2 * .pi }
        return x - .pi
    }
}

/// Finds a named clip in a loaded model, falling back to nil.
func animation(named name: String?, in entity: Entity) -> AnimationResource? {
    guard let name else { return nil }
    return entity.availableAnimations.first { $0.name == name }
}
