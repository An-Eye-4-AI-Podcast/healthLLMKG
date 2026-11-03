import RealityKit
import simd

/// Loads a creature USDZ (or a procedural stand-in) and dresses it with every component the
/// portal needs: crossing, input, collisions, its own blendable light, and the behaviour state.
enum CreatureFactory {

    struct Result {
        let entity: Entity
        /// Bundle assets that were not found (a stand-in was used).
        let missing: [String]
    }

    @MainActor
    static func make(spec: CreatureSpec,
                     config: EnvironmentConfig,
                     videoLight: EnvironmentResource?,
                     neutralLight: EnvironmentResource?) async -> Result {
        var missing: [String] = []

        // 1. Geometry: real asset if present, otherwise a primitive stand-in.
        let model: Entity
        if let loaded = try? await Entity(named: spec.modelName, in: .main) {
            model = loaded
        } else {
            missing.append("Models/\(spec.modelName).usdz")
            model = PlaceholderCreatures.make(spec.placeholder)
        }
        model.name = "model"
        model.scale = SIMD3(repeating: spec.scale)
        model.orientation = simd_quatf(angle: spec.modelYawOffset, axis: [0, 1, 0])

        let root = Entity()
        root.name = spec.id
        root.addChild(model)
        root.position = spec.homePosition

        // 2. Hit-testing for taps and the system hover highlight.
        let bounds = root.visualBounds(relativeTo: root)
        let shape = ShapeResource.generateBox(size: simd_max(bounds.extents, SIMD3(repeating: 0.05)))
            .offsetBy(translation: bounds.center)
        root.components.set(CollisionComponent(shapes: [shape]))
        root.components.set(InputTargetComponent())
        root.components.set(HoverEffectComponent())

        // 3. Allow the creature to cross out of the portal into the room.
        if spec.crossesPortal {
            setCrossing(on: root)
        }

        // 4. Lighting: its own probe, blended between the video and a neutral room.
        if let videoLight, let neutralLight {
            VideoLightingRig.attachCreatureLight(video: videoLight,
                                                 neutral: neutralLight,
                                                 intensityExponent: config.lightingIntensityExponent,
                                                 to: root)
        }

        // 5. Idle animation from the asset, if any.
        var hasReaction = false
        if let idle = animation(named: spec.idleAnimationName, in: model) ?? model.availableAnimations.first {
            model.playAnimation(idle.repeat(), transitionDuration: 0.25, startsPaused: false)
        }
        if animation(named: spec.reactionAnimationName, in: model) != nil {
            hasReaction = true
        }

        // 6. Effects: a reaction burst (off until tapped or touched) and, for most creatures,
        //    a continuous trail (bubbles, horn sparkle, scale shimmer).
        let fx = Atmosphere.makeReactionFX(for: spec.placeholder)
        fx.position = [0, bounds.center.y, bounds.max.z * 0.6]
        fx.isEnabled = false
        root.addChild(fx)
        if let trail = Atmosphere.makeTrail(for: spec.placeholder, bounds: bounds) {
            root.addChild(trail)
        }

        // 7. Voice: clips play from the creature's own body, so they pan and attenuate with it.
        if let voice = await VoiceComponent.load(spec.voices ?? .default(for: spec.placeholder), startingAt: 0) {
            root.components.set(SpatialAudioComponent(gain: -4, directivity: .beam(focus: 0.4)))
            root.components.set(voice)
        }

        // 8. Behaviour state.
        root.components.set(CreatureComponent(
            spec: spec,
            phaseDuration: spec.idleSeconds * Double.random(in: 0.3...1.0),
            portalPlaneZ: config.portalPosition.z,
            portalCenter: config.portalPosition,
            noseOffset: max(bounds.max.z, 0.05),
            touchLocal: [0, bounds.center.y + bounds.extents.y * 0.2, bounds.max.z * 0.9],
            hasReactionClip: hasReaction
        ))
        return Result(entity: root, missing: missing)
    }

    /// `PortalCrossingComponent` is applied to the root and every model node so the whole body
    /// is allowed through the plane, however the USDZ is nested.
    private static func setCrossing(on entity: Entity) {
        entity.components.set(PortalCrossingComponent())
        for child in entity.children { setCrossing(on: child) }
    }

    /// Finds the creature root for whatever sub-entity a tap landed on.
    static func creatureRoot(of entity: Entity) -> Entity? {
        var current: Entity? = entity
        while let e = current {
            if e.components.has(CreatureComponent.self) { return e }
            current = e.parent
        }
        return nil
    }
}
