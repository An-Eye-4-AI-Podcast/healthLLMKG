import RealityKit
import UIKit
import simd

/// Tag for the one emitter that sits on the portal plane and bursts when a creature crosses.
struct PortalRippleComponent: Component {}

/// Tag for an emitter riding on a creature that only runs while it moves (bubble trail).
struct TrailComponent: Component {
    var onlyWhileMoving: Bool
}

/// Particle "weather" per world, creature-attached trails, the spill of particles out of the
/// portal into the room, the crossing ripple, tap reactions, and the ambient audio bed.
enum Atmosphere {

    // MARK: World weather (inside the portal)

    /// A slab of drifting particles just inside the portal so the world feels alive.
    static func makeEmitter(style: AtmosphereStyle,
                            portalPosition: SIMD3<Float>,
                            portalSize: SIMD2<Float>) -> Entity {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .box
        emitter.emitterShapeSize = [portalSize.x * 1.4, portalSize.y * 1.2, 2.5]
        emitter.birthLocation = .volume
        emitter.isEmitting = true

        switch style {
        case .bubbles:   styleBubbles(&emitter, birthRate: 40, size: 0.012)
        case .petals:    stylePetals(&emitter, birthRate: 25)
        case .dustMotes: styleDust(&emitter, birthRate: 30)
        }

        let entity = Entity()
        entity.name = "atmosphere"
        entity.position = portalPosition + [0, 0, -1.2]
        entity.components.set(emitter)
        return entity
    }

    // MARK: Spill (in the room, outside the portal)

    /// Particles that leak out of the portal plane into the user's space: bubbles float up and
    /// out of the trench, sparkle motes drift out of the valley, sunlit dust out of the den.
    /// Lives in the main scene, so nothing clips it.
    static func makeSpill(style: AtmosphereStyle,
                          portalPosition: SIMD3<Float>,
                          portalSize: SIMD2<Float>) -> Entity {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .box
        emitter.emitterShapeSize = [portalSize.x * 0.9, portalSize.y * 0.9, 0.05]
        emitter.birthLocation = .volume
        emitter.birthDirection = .local
        emitter.emissionDirection = [0, 0, 1]          // out of the plane, toward the viewer
        emitter.isEmitting = true

        switch style {
        case .bubbles:
            styleBubbles(&emitter, birthRate: 14, size: 0.014)
            emitter.speed = 0.18
            emitter.speedVariation = 0.08
            emitter.mainEmitter.acceleration = [0, 0.16, 0.02]
            emitter.mainEmitter.lifeSpan = 6
        case .petals:
            styleSparkle(&emitter, birthRate: 24, size: 0.008,
                         color: UIColor(red: 1.0, green: 0.86, blue: 0.95, alpha: 0.9))
            emitter.speed = 0.12
            emitter.speedVariation = 0.08
            emitter.mainEmitter.acceleration = [0, -0.02, 0]
            emitter.mainEmitter.lifeSpan = 5
            emitter.mainEmitter.noiseStrength = 0.4
        case .dustMotes:
            styleDust(&emitter, birthRate: 20)
            emitter.speed = 0.04
            emitter.speedVariation = 0.03
            emitter.mainEmitter.lifeSpan = 9
        }

        let entity = Entity()
        entity.name = "spill"
        entity.position = portalPosition + [0, 0, 0.08]
        entity.components.set(emitter)
        return entity
    }

    /// A ring burst on the portal plane. `CreatureSystem` moves it to the crossing point and
    /// fires it whenever a creature's nose breaks the plane in either direction.
    static func makeRipple(style: AtmosphereStyle) -> Entity {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .torus
        emitter.emitterShapeSize = [0.35, 0.35, 0.03]
        emitter.birthLocation = .surface
        emitter.birthDirection = .normal
        emitter.isEmitting = false
        emitter.burstCount = 160
        emitter.burstCountVariation = 40
        emitter.speed = 0.5
        emitter.speedVariation = 0.3
        switch style {
        case .bubbles:
            styleBubbles(&emitter, birthRate: 0, size: 0.012)
            emitter.mainEmitter.lifeSpan = 1.6
            emitter.mainEmitter.acceleration = [0, 0.3, 0]
        case .petals:
            styleSparkle(&emitter, birthRate: 0, size: 0.012,
                         color: UIColor(red: 1.0, green: 0.92, blue: 0.6, alpha: 1))
            emitter.mainEmitter.lifeSpan = 1.2
        case .dustMotes:
            styleSparkle(&emitter, birthRate: 0, size: 0.008,
                         color: UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.9))
            emitter.mainEmitter.lifeSpan = 1.4
        }
        emitter.mainEmitter.dampingFactor = 2.5

        let entity = Entity()
        entity.name = "ripple"
        entity.components.set(emitter)
        entity.components.set(PortalRippleComponent())
        return entity
    }

    // MARK: Creature-attached effects

    /// A continuous emitter riding on the creature. Narwhal: bubbles from the blowhole while it
    /// swims. Unicorn: a sparkle trail off the horn. Mermaid: shimmer along the tail. Puppy: none.
    static func makeTrail(for kind: PlaceholderKind, bounds: BoundingBox) -> Entity? {
        var emitter = ParticleEmitterComponent()
        emitter.isEmitting = true
        let entity = Entity()
        entity.name = "trail"
        switch kind {
        case .narwhal:
            styleBubbles(&emitter, birthRate: 18, size: 0.01)
            emitter.emitterShape = .sphere
            emitter.emitterShapeSize = [0.05, 0.05, 0.05]
            emitter.speed = 0.08
            emitter.mainEmitter.acceleration = [0, 0.25, -0.05]   // rise and stream behind
            emitter.mainEmitter.lifeSpan = 3
            entity.position = [0, bounds.max.y - 0.02, bounds.max.z * 0.35]   // blowhole
            entity.components.set(TrailComponent(onlyWhileMoving: true))
        case .unicorn:
            styleSparkle(&emitter, birthRate: 40, size: 0.006,
                         color: UIColor(red: 1.0, green: 0.9, blue: 0.55, alpha: 1))
            emitter.emitterShape = .sphere
            emitter.emitterShapeSize = [0.06, 0.06, 0.06]
            emitter.speed = 0.05
            emitter.mainEmitter.acceleration = [0, -0.05, 0]
            emitter.mainEmitter.lifeSpan = 1.4
            entity.position = [0, bounds.max.y - 0.03, bounds.max.z - 0.22]   // horn tip
            entity.components.set(TrailComponent(onlyWhileMoving: false))
        case .mermaid:
            styleSparkle(&emitter, birthRate: 14, size: 0.005,
                         color: UIColor(red: 0.6, green: 1.0, blue: 0.95, alpha: 0.9))
            emitter.emitterShape = .cylinder
            emitter.emitterShapeSize = [0.3, 0.9, 0.3]
            emitter.speed = 0.02
            emitter.mainEmitter.lifeSpan = 2
            entity.position = [0, bounds.max.y * 0.3, 0]
            entity.components.set(TrailComponent(onlyWhileMoving: false))
        case .puppy:
            return nil
        }
        entity.components.set(emitter)
        return entity
    }

    /// Short burst attached to each creature; `CreatureSystem` toggles it on tap or touch.
    /// Water creatures blow bubbles, land creatures throw sparkles.
    static func makeReactionFX(for kind: PlaceholderKind) -> Entity {
        var emitter = ParticleEmitterComponent.Presets.magic
        emitter.isEmitting = false
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.25, 0.25, 0.25]
        emitter.mainEmitter.birthRate = 400
        emitter.mainEmitter.lifeSpan = 1.0
        emitter.mainEmitter.size = 0.01
        switch kind {
        case .narwhal, .mermaid:
            styleBubbles(&emitter, birthRate: 300, size: 0.014)
            emitter.speed = 0.4
            emitter.mainEmitter.acceleration = [0, 0.4, 0]
            emitter.mainEmitter.lifeSpan = 1.6
        case .unicorn:
            emitter.mainEmitter.color = .evolving(
                start: .single(UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1)),
                end:   .single(UIColor(red: 0.85, green: 0.6, blue: 1.0, alpha: 0)))
        case .puppy:
            emitter.mainEmitter.color = .evolving(
                start: .single(UIColor(red: 1.0, green: 0.55, blue: 0.65, alpha: 1)),
                end:   .single(UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0)))
        }
        let entity = Entity()
        entity.name = "reactionFX"
        entity.components.set(emitter)
        return entity
    }

    // MARK: Styles

    private static func styleBubbles(_ e: inout ParticleEmitterComponent, birthRate: Float, size: Float) {
        e.speed = max(e.speed, 0.06)
        e.speedVariation = 0.04
        e.mainEmitter.birthRate = birthRate
        e.mainEmitter.lifeSpan = 7
        e.mainEmitter.lifeSpanVariation = 2
        e.mainEmitter.size = size
        e.mainEmitter.sizeVariation = size * 0.6
        e.mainEmitter.color = .constant(.single(UIColor(red: 0.75, green: 0.9, blue: 1.0, alpha: 0.75)))
        e.mainEmitter.acceleration = [0, 0.12, 0]
        e.mainEmitter.noiseStrength = 0.15
        e.mainEmitter.blendMode = .additive
        e.mainEmitter.opacityCurve = .linearFadeInOut
    }

    private static func stylePetals(_ e: inout ParticleEmitterComponent, birthRate: Float) {
        e.speed = 0.08
        e.speedVariation = 0.05
        e.mainEmitter.birthRate = birthRate
        e.mainEmitter.lifeSpan = 9
        e.mainEmitter.lifeSpanVariation = 3
        e.mainEmitter.size = 0.02
        e.mainEmitter.sizeVariation = 0.01
        e.mainEmitter.color = .evolving(
            start: .single(UIColor(red: 1.0, green: 0.72, blue: 0.85, alpha: 0.95)),
            end:   .single(UIColor(red: 1.0, green: 0.92, blue: 0.97, alpha: 0.6)))
        e.mainEmitter.acceleration = [0.02, -0.12, 0]
        e.mainEmitter.noiseStrength = 0.5
        e.mainEmitter.angularSpeed = 1.2
        e.mainEmitter.blendMode = .alpha
        e.mainEmitter.opacityCurve = .linearFadeInOut
    }

    private static func styleDust(_ e: inout ParticleEmitterComponent, birthRate: Float) {
        e.speed = 0.015
        e.speedVariation = 0.01
        e.mainEmitter.birthRate = birthRate
        e.mainEmitter.lifeSpan = 12
        e.mainEmitter.lifeSpanVariation = 4
        e.mainEmitter.size = 0.004
        e.mainEmitter.sizeVariation = 0.003
        e.mainEmitter.color = .constant(.single(UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.55)))
        e.mainEmitter.acceleration = [0, 0.005, 0]
        e.mainEmitter.noiseStrength = 0.08
        e.mainEmitter.blendMode = .additive
        e.mainEmitter.opacityCurve = .gradualFadeInOut
    }

    private static func styleSparkle(_ e: inout ParticleEmitterComponent, birthRate: Float, size: Float, color: UIColor) {
        e.mainEmitter.birthRate = birthRate
        e.mainEmitter.lifeSpan = 1.5
        e.mainEmitter.lifeSpanVariation = 0.5
        e.mainEmitter.size = size
        e.mainEmitter.sizeVariation = size * 0.5
        e.mainEmitter.color = .evolving(start: .single(color), end: .single(color.withAlphaComponent(0)))
        e.mainEmitter.blendMode = .additive
        e.mainEmitter.opacityCurve = .quickFadeInOut
        e.mainEmitter.noiseStrength = 0.2
        e.mainEmitter.angularSpeed = 3
    }

    // MARK: Audio

    /// Looping ambience anchored at the portal. Returns nil when the file is not in the bundle.
    @MainActor
    static func makeAmbience(named baseName: String) async -> Entity? {
        let candidates = ["\(baseName).m4a", "\(baseName).mp3", "\(baseName).wav"]
        for file in candidates {
            guard Bundle.main.url(forResource: file, withExtension: nil) != nil else { continue }
            guard let resource = try? await AudioFileResource(named: file,
                                                               configuration: .init(shouldLoop: true)) else { continue }
            let entity = Entity()
            entity.name = "ambience"
            entity.components.set(SpatialAudioComponent(gain: -8, directivity: .beam(focus: 0.3)))
            entity.playAudio(resource)
            return entity
        }
        return nil
    }
}
