import RealityKit
import AVFoundation
import simd

/// Assembles one portal world: the clipped `WorldComponent` sub-scene, the video dome and its
/// lighting, the portal plane, creatures, particles and audio. Owns the player for its lifetime.
@MainActor
final class PortalScene {
    let environment: WonderEnvironment
    let config: EnvironmentConfig

    /// Add this to `RealityViewContent`.
    let root = Entity()
    private let world = Entity()
    private var portal = Entity()
    private(set) var creatures: [Entity] = []
    private(set) var playback: VideoPlayback?

    private var videoLight: EnvironmentResource?
    private var neutralLight: EnvironmentResource?

    /// Assets that were not found in the bundle; stand-ins were used instead.
    private(set) var missingAssets: [String] = []

    /// Where the dome is centred — roughly the seated/standing eye height of the viewer.
    private let eyePosition: SIMD3<Float> = [0, 1.5, 0]

    init(environment: WonderEnvironment) {
        self.environment = environment
        self.config = environment.config
    }

    // MARK: Build

    func build(ambience: Bool) async {
        root.name = "portalRoot-\(environment.rawValue)"

        // The world: everything inside is only visible through the portal.
        world.name = "world"
        world.components.set(WorldComponent())
        root.addChild(world)

        await buildBackdrop()
        await buildLighting()
        buildPortal()
        await buildCreatures()
        buildAtmosphere()
        if ambience { await buildAmbience() }

        playback?.play()
    }

    private func buildBackdrop() async {
        // Solid colour sphere first so a 180° video has something behind it.
        if let backdrop = try? ImmersiveVideoDome.makeBackdrop(color: config.backdropColor) {
            backdrop.position = eyePosition
            world.addChild(backdrop)
        }

        guard let url = videoURL() else {
            missingAssets.append("Videos/\(config.videoName).mp4")
            return
        }
        let playback = VideoPlayback(url: url)
        self.playback = playback
        do {
            let dome = try ImmersiveVideoDome.makeEntity(playback: playback, projection: config.projection)
            dome.position = eyePosition
            world.addChild(dome)
        } catch {
            missingAssets.append("dome mesh (\(error))")
        }
    }

    private func buildLighting() async {
        neutralLight = try? await VideoLightingRig.neutralEnvironmentResource()
        if let url = playback?.url {
            videoLight = try? await VideoLightingRig.environmentResource(from: url,
                                                                        projection: config.projection,
                                                                        name: "\(environment.rawValue)-video-ibl")
        }
        // Everything in the world is lit by the footage; fall back to the neutral probe.
        if let light = videoLight ?? neutralLight {
            VideoLightingRig.attachWorldLight(light, to: world, intensityExponent: config.lightingIntensityExponent)
        }
    }

    private func buildPortal() {
        let mesh = MeshResource.generatePlane(width: config.portalSize.x,
                                              height: config.portalSize.y,
                                              cornerRadius: 0.14)
        let portal = ModelEntity(mesh: mesh, materials: [PortalMaterial()])
        portal.name = "portal"
        portal.position = config.portalPosition          // faces +Z, toward the viewer
        portal.components.set(PortalComponent(
            target: world,
            clippingMode: .plane(.positiveZ),            // the world is cut at the plane…
            crossingMode: .plane(.positiveZ)             // …but tagged entities may step through
        ))
        root.addChild(portal)
        self.portal = portal
    }

    private func buildCreatures() async {
        for spec in config.creatures {
            let built = await CreatureFactory.make(spec: spec,
                                                   config: config,
                                                   videoLight: videoLight ?? neutralLight,
                                                   neutralLight: neutralLight)
            missingAssets += built.missing
            world.addChild(built.entity)
            creatures.append(built.entity)
        }
    }

    private func buildAtmosphere() {
        world.addChild(Atmosphere.makeEmitter(style: config.atmosphere,
                                              portalPosition: config.portalPosition,
                                              portalSize: config.portalSize))
    }

    private func buildAmbience() async {
        guard let name = config.ambientAudioName else { return }
        if let audio = await Atmosphere.makeAmbience(named: name) {
            audio.position = config.portalPosition
            root.addChild(audio)
        } else {
            missingAssets.append("Audio/\(name).m4a")
        }
    }

    // MARK: Runtime

    /// Re-samples the video at its current time so the lighting follows the footage.
    func refreshLighting() async {
        guard let playback, let neutralLight else { return }
        let time = playback.player.currentTime()
        guard let fresh = try? await VideoLightingRig.environmentResource(
            from: playback.url, projection: config.projection,
            at: time, name: "\(environment.rawValue)-ibl-\(Int(time.seconds))") else { return }
        videoLight = fresh
        VideoLightingRig.attachWorldLight(fresh, to: world, intensityExponent: config.lightingIntensityExponent)
        for creature in creatures {
            guard var lb = creature.components[LightBlendComponent.self] else { continue }
            lb.video = fresh
            creature.components.set(lb)
            creature.components.set(ImageBasedLightComponent(source: .blend(fresh, neutralLight, lb.blend),
                                                             intensityExponent: lb.intensityExponent))
        }
    }

    /// Tap handler: the creature under the tap reacts; a tap on the portal itself summons everyone.
    func handleTap(on entity: Entity) {
        if let creature = CreatureFactory.creatureRoot(of: entity) {
            modify(creature) { $0.reactionRequested = true }
        } else {
            summonAll()
        }
    }

    func summonAll() {
        for creature in creatures {
            modify(creature) { if $0.phase == .idle { $0.summonRequested = true } }
        }
    }

    func tearDown() {
        playback?.pause()
        root.removeFromParent()
    }

    // MARK: Helpers

    private func modify(_ creature: Entity, _ change: (inout CreatureComponent) -> Void) {
        guard var c = creature.components[CreatureComponent.self] else { return }
        change(&c)
        creature.components.set(c)
    }

    private func videoURL() -> URL? {
        for ext in ["mp4", "mov", "m4v"] {
            if let url = Bundle.main.url(forResource: config.videoName, withExtension: ext) { return url }
        }
        return nil
    }
}
