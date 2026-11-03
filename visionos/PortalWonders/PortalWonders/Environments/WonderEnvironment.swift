import SwiftUI
import UIKit
import RealityKit
import simd

/// How the backing video was shot.
enum VideoProjection: String, Codable {
    /// Half-equirectangular (VR180 mono). Covers the front hemisphere; a backdrop fills the rest.
    case equirectangular180
    /// Full equirectangular (360 mono).
    case equirectangular360
}

/// The particle "weather" in each world.
enum AtmosphereStyle { case bubbles, petals, dustMotes }

/// What the creature does between visits to the portal plane.
enum CreatureLocomotion { case swim, graze, bound }

/// Stand-in geometry used until a real USDZ is dropped into Resources/Models.
enum PlaceholderKind { case narwhal, mermaid, unicorn, puppy }

/// Everything needed to spawn one creature.
struct CreatureSpec: Identifiable {
    var id: String
    /// Basename of a `.usdz` in Resources/Models (loaded with `Entity(named:)`).
    var modelName: String
    var placeholder: PlaceholderKind
    var scale: Float = 1
    /// Where the creature lives deep inside the world (room-space metres).
    var homePosition: SIMD3<Float>
    /// Where the creature pauses when it pokes through the portal (in front of the plane).
    var visitPosition: SIMD3<Float>
    var locomotion: CreatureLocomotion
    /// Seconds idling at home before the next approach; a random jitter is added.
    var idleSeconds: Double = 8
    var approachSeconds: Double = 5
    var visitSeconds: Double = 7
    var retreatSeconds: Double = 4
    /// Rotate the model so that its nose faces +Z (toward the user). USDZ exports differ.
    var modelYawOffset: Float = 0
    /// Optional named animations inside the USDZ (falls back to the first clip / procedural bob).
    var idleAnimationName: String? = nil
    var reactionAnimationName: String? = nil
    /// Whether the creature ever crosses the portal plane (mermaids stay inside, narwhals don't).
    var crossesPortal = true
    /// Vocalisation clips; nil uses the defaults for the placeholder kind (see VoiceSet).
    var voices: VoiceSet? = nil
}

/// Static configuration for one portal world.
struct EnvironmentConfig {
    var videoName: String
    var projection: VideoProjection
    /// 2:1 equirectangular still (jpg/png in Resources/Panoramas) shown when the video is absent.
    var panoramaName: String
    var ambientAudioName: String?
    /// Exponent applied to the video-derived image-based light (2^x). 0 = as-is.
    var lightingIntensityExponent: Float = 0
    /// Color behind a 180° dome and the fog tint at the portal rim.
    var backdropColor: UIColor
    var portalSize: SIMD2<Float>          // width, height in metres
    var portalPosition: SIMD3<Float>      // room-space, +Z faces the user
    var atmosphere: AtmosphereStyle
    var creatures: [CreatureSpec]
}

/// The three worlds. Add a case here and the picker, portal and ECS pick it up.
enum WonderEnvironment: String, CaseIterable, Identifiable, Codable {
    case trench, valley, den

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trench: return "Mariana Trench"
        case .valley: return "Unicorn Valley"
        case .den:    return "Puppy Den"
        }
    }

    var tagline: String {
        switch self {
        case .trench: return "Narwhals and mermaids, eleven kilometres down."
        case .valley: return "A flower-choked valley where unicorns graze."
        case .den:    return "A sunlit couch, one very excited puppy."
        }
    }

    var symbol: String {
        switch self {
        case .trench: return "water.waves"
        case .valley: return "mountain.2.fill"
        case .den:    return "pawprint.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .trench: return [Color(red: 0.02, green: 0.10, blue: 0.30), Color(red: 0.00, green: 0.35, blue: 0.55)]
        case .valley: return [Color(red: 0.55, green: 0.30, blue: 0.75), Color(red: 0.95, green: 0.65, blue: 0.80)]
        case .den:    return [Color(red: 0.85, green: 0.55, blue: 0.30), Color(red: 0.98, green: 0.85, blue: 0.65)]
        }
    }

    var hint: String {
        switch self {
        case .trench: return "Hold your hand out. The narwhal swims through to nudge it."
        case .valley: return "Reach toward the horn. Touch it for sparkles."
        case .den:    return "Reach toward the portal, then look down. The puppy comes to your feet."
        }
    }

    // MARK: - Scene configuration

    var config: EnvironmentConfig {
        switch self {
        case .trench:
            return EnvironmentConfig(
                videoName: "trench_360",
                projection: .equirectangular360,
                panoramaName: "trench_pano",
                ambientAudioName: "trench_ambience",
                lightingIntensityExponent: 0.5,
                backdropColor: UIColor(red: 0.01, green: 0.05, blue: 0.14, alpha: 1),
                portalSize: [1.8, 2.2],
                portalPosition: [0, 1.3, -2.6],
                atmosphere: .bubbles,
                creatures: [
                    CreatureSpec(
                        id: "narwhal",
                        modelName: "narwhal",
                        placeholder: .narwhal,
                        scale: 1.0,
                        homePosition: [0.8, 1.5, -4.8],
                        visitPosition: [0.0, 1.35, -2.15],   // head and half the body in the room, tusk tip ~0.6 m from your face
                        locomotion: .swim,
                        idleSeconds: 6, approachSeconds: 6, visitSeconds: 8, retreatSeconds: 5,
                        idleAnimationName: "swim", reactionAnimationName: "spin"
                    ),
                    CreatureSpec(
                        id: "mermaid",
                        modelName: "mermaid",
                        placeholder: .mermaid,
                        scale: 1.0,
                        homePosition: [-0.9, 0.9, -4.0],
                        visitPosition: [-0.6, 1.0, -2.9],   // comes to the glass, never through it
                        locomotion: .swim,
                        idleSeconds: 10, approachSeconds: 5, visitSeconds: 6, retreatSeconds: 4,
                        idleAnimationName: "idle", reactionAnimationName: "wave",
                        crossesPortal: false
                    )
                ]
            )
        case .valley:
            return EnvironmentConfig(
                videoName: "valley_180",
                projection: .equirectangular180,
                panoramaName: "valley_pano",
                ambientAudioName: "valley_ambience",
                lightingIntensityExponent: 0.8,
                backdropColor: UIColor(red: 0.78, green: 0.80, blue: 0.92, alpha: 1),
                portalSize: [2.2, 2.3],
                portalPosition: [0, 1.15, -2.2],   // bottom edge on the floor so hooves cross inside the frame
                atmosphere: .petals,
                creatures: [
                    CreatureSpec(
                        id: "unicorn",
                        modelName: "unicorn",
                        placeholder: .unicorn,
                        scale: 1.0,
                        homePosition: [0.6, 0.0, -5.0],
                        visitPosition: [0.0, 0.0, -1.75],   // head, horn and forelegs through the portal
                        locomotion: .graze,
                        idleSeconds: 7, approachSeconds: 7, visitSeconds: 9, retreatSeconds: 6,
                        idleAnimationName: "walk", reactionAnimationName: "rear"
                    )
                ]
            )
        case .den:
            return EnvironmentConfig(
                videoName: "den_180",
                projection: .equirectangular180,
                panoramaName: "den_pano",
                ambientAudioName: "den_ambience",
                lightingIntensityExponent: 0.3,
                backdropColor: UIColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1),
                portalSize: [1.6, 1.56],
                portalPosition: [0, 0.78, -1.8],   // floor-to-shoulder window: the pup jumps down through it
                atmosphere: .dustMotes,
                creatures: [
                    CreatureSpec(
                        id: "puppy",
                        modelName: "puppy",
                        placeholder: .puppy,
                        scale: 1.0,
                        homePosition: [0.2, 0.55, -3.0],    // on the couch cushion in the video
                        visitPosition: [0.2, 0.0, -1.0],    // bounds off the couch and lands at your feet
                        locomotion: .bound,
                        idleSeconds: 4, approachSeconds: 3, visitSeconds: 10, retreatSeconds: 3,
                        idleAnimationName: "sit", reactionAnimationName: "jump"
                    )
                ]
            )
        }
    }
}
