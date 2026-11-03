import RealityKit
import UIKit
import simd

/// Particle "weather" per world, the tap-reaction sparkle burst, and the ambient audio bed.
enum Atmosphere {

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
        case .bubbles:
            emitter.speed = 0.06
            emitter.speedVariation = 0.04
            emitter.mainEmitter.birthRate = 40
            emitter.mainEmitter.lifeSpan = 7
            emitter.mainEmitter.lifeSpanVariation = 2
            emitter.mainEmitter.size = 0.012
            emitter.mainEmitter.sizeVariation = 0.008
            emitter.mainEmitter.color = .constant(.single(UIColor(red: 0.75, green: 0.9, blue: 1.0, alpha: 0.75)))
            emitter.mainEmitter.acceleration = [0, 0.12, 0]
            emitter.mainEmitter.noiseStrength = 0.15
            emitter.mainEmitter.blendMode = .additive
            emitter.mainEmitter.opacityCurve = .linearFadeInOut
        case .petals:
            emitter.speed = 0.08
            emitter.speedVariation = 0.05
            emitter.mainEmitter.birthRate = 25
            emitter.mainEmitter.lifeSpan = 9
            emitter.mainEmitter.lifeSpanVariation = 3
            emitter.mainEmitter.size = 0.02
            emitter.mainEmitter.sizeVariation = 0.01
            emitter.mainEmitter.color = .evolving(
                start: .single(UIColor(red: 1.0, green: 0.72, blue: 0.85, alpha: 0.95)),
                end:   .single(UIColor(red: 1.0, green: 0.92, blue: 0.97, alpha: 0.6)))
            emitter.mainEmitter.acceleration = [0.02, -0.12, 0]
            emitter.mainEmitter.noiseStrength = 0.5
            emitter.mainEmitter.angularSpeed = 1.2
            emitter.mainEmitter.blendMode = .alpha
            emitter.mainEmitter.opacityCurve = .linearFadeInOut
        case .dustMotes:
            emitter.speed = 0.015
            emitter.speedVariation = 0.01
            emitter.mainEmitter.birthRate = 30
            emitter.mainEmitter.lifeSpan = 12
            emitter.mainEmitter.lifeSpanVariation = 4
            emitter.mainEmitter.size = 0.004
            emitter.mainEmitter.sizeVariation = 0.003
            emitter.mainEmitter.color = .constant(.single(UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.55)))
            emitter.mainEmitter.acceleration = [0, 0.005, 0]
            emitter.mainEmitter.noiseStrength = 0.08
            emitter.mainEmitter.blendMode = .additive
            emitter.mainEmitter.opacityCurve = .gradualFadeInOut
        }

        let entity = Entity()
        entity.name = "atmosphere"
        entity.position = portalPosition + [0, 0, -1.2]   // centred just behind the plane
        entity.components.set(emitter)
        return entity
    }

    /// Short magic burst attached to each creature; `CreatureSystem` toggles it on tap.
    static func makeReactionSparkles() -> Entity {
        var emitter = ParticleEmitterComponent.Presets.magic
        emitter.isEmitting = false
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.25, 0.25, 0.25]
        emitter.mainEmitter.birthRate = 400
        emitter.mainEmitter.lifeSpan = 1.0
        emitter.mainEmitter.size = 0.01
        let entity = Entity()
        entity.name = "reactionFX"
        entity.components.set(emitter)
        return entity
    }

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
