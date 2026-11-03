import RealityKit
import Foundation

/// Which bundled clips a creature uses for each occasion (basenames in Resources/Audio).
struct VoiceSet {
    /// Played once when the creature reaches the portal plane.
    var arrive: [String]
    /// Played when the user taps the creature.
    var react: [String]
    /// Played now and then while idling deep in the world.
    var idle: [String]
    /// Seconds between idle calls (a random value in this range each time).
    var idleEvery: ClosedRange<Double> = 9...22
    /// Idle calls are quieter than arrivals; this is the offset in dB.
    var idleGain: Double = -8

    static func `default`(for kind: PlaceholderKind) -> VoiceSet {
        switch kind {
        case .narwhal:
            return VoiceSet(arrive: ["narwhal_whistle"], react: ["narwhal_clicks"],
                            idle: ["narwhal_knocks", "narwhal_whistle"])
        case .mermaid:
            // She sings. Long siren phrases from deep in the trench, overlapping the narwhal's
            // whistles and knocks; a short call when she reaches the glass.
            return VoiceSet(arrive: ["mermaid_call"], react: ["mermaid_siren_a", "mermaid_call"],
                            idle: ["mermaid_siren_a", "mermaid_siren_b", "mermaid_lure", "mermaid_hum"],
                            idleEvery: 7...16, idleGain: -5)
        case .unicorn:
            return VoiceSet(arrive: ["unicorn_nicker"], react: ["unicorn_whinny"],
                            idle: ["unicorn_snort", "unicorn_nicker"])
        case .puppy:
            return VoiceSet(arrive: ["puppy_bark"], react: ["puppy_yip", "puppy_bark"],
                            idle: ["puppy_whine", "puppy_yip"])
        }
    }
}

/// Loaded clips plus the scheduling state `CreatureSystem` needs to play them.
struct VoiceComponent: Component {
    var arrive: [AudioFileResource]
    var react: [AudioFileResource]
    var idle: [AudioFileResource]
    /// Creature-local clock value at which the next idle call may fire.
    var nextIdleCallAt: Double
    var idleEvery: ClosedRange<Double>
    var idleGain: Double
    /// Minimum spacing between any two calls, so taps cannot machine-gun the bark.
    var cooldown: Double = 1.2
    var lastCallAt: Double = -10

    /// Loads whatever clips exist in the bundle; missing ones are skipped silently.
    @MainActor
    static func load(_ set: VoiceSet, startingAt time: Double) async -> VoiceComponent? {
        async let a = loadClips(set.arrive)
        async let r = loadClips(set.react)
        async let i = loadClips(set.idle)
        let (arrive, react, idle) = await (a, r, i)
        guard !(arrive.isEmpty && react.isEmpty && idle.isEmpty) else { return nil }
        return VoiceComponent(arrive: arrive, react: react, idle: idle,
                              nextIdleCallAt: time + Double.random(in: 4...12),
                              idleEvery: set.idleEvery, idleGain: set.idleGain)
    }

    @MainActor
    private static func loadClips(_ names: [String]) async -> [AudioFileResource] {
        var clips: [AudioFileResource] = []
        for name in names {
            for ext in ["m4a", "wav", "mp3"] {
                guard Bundle.main.url(forResource: name, withExtension: ext) != nil else { continue }
                if let clip = try? await AudioFileResource(named: "\(name).\(ext)",
                                                           configuration: .init(shouldLoop: false)) {
                    clips.append(clip)
                    break
                }
            }
        }
        return clips
    }
}
