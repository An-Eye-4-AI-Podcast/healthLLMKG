import RealityKit
import AVFoundation
import CoreGraphics
import UIKit
import simd

/// Turns frames of the backing video into image-based lighting (IBL), and builds the neutral
/// "room-ish" probe that the creature blends toward as it protrudes into the user's space.
///
/// Lighting model (mirrors Encounter Dinosaurs):
///   • Everything inside the portal world is lit by an `ImageBasedLightComponent` whose
///     environment map is sampled from the video itself. So the *back* of a creature reflects
///     the trench/valley/den footage.
///   • Geometry that has crossed the portal plane (`PortalCrossingComponent`) is rendered by the
///     main pass in the user's room, where visionOS applies the real-world environment lighting.
///   • To soften the hand-off, each creature carries its own light whose source is
///     `.blend(videoIBL, neutralIBL, t)`; `CreatureSystem` drives `t` from how far the creature
///     has pushed through the plane.
enum VideoLightingRig {

    // MARK: Video → environment map

    /// Grabs a frame of the video and converts it into an `EnvironmentResource`.
    /// For 180° footage the frame is centred in a 2:1 canvas padded with its average colour,
    /// so the lighting behind the creature is still sensible.
    static func environmentResource(from url: URL,
                                    projection: VideoProjection,
                                    at time: CMTime = .zero,
                                    name: String) async throws -> EnvironmentResource {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        let (frame, _) = try await generator.image(at: time)

        let equirect: CGImage
        switch projection {
        case .equirectangular360: equirect = frame
        case .equirectangular180: equirect = try pad180To360(frame)
        }
        return try await EnvironmentResource(equirectangular: equirect, withName: name)
    }

    /// Builds the probe straight from a 2:1 equirectangular still (the no-video path).
    static func environmentResource(fromEquirectangular image: CGImage,
                                    name: String) async throws -> EnvironmentResource {
        try await EnvironmentResource(equirectangular: image, withName: name)
    }

    /// A soft studio probe: warm bright ceiling, grey horizon, dark floor. Used as the
    /// "other side" of the blend so protruding geometry stops looking like it is still underwater.
    static func neutralEnvironmentResource(name: String = "neutral-room") async throws -> EnvironmentResource {
        let size = CGSize(width: 256, height: 128)
        let image = try renderImage(size: size) { ctx in
            let colors = [
                UIColor(white: 1.0, alpha: 1).cgColor,  // top (zenith)
                UIColor(white: 0.55, alpha: 1).cgColor, // horizon
                UIColor(white: 0.18, alpha: 1).cgColor  // bottom (floor)
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) else {
                throw LightingError.gradientFailed
            }
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: size.height),
                                   end: CGPoint(x: 0, y: 0),
                                   options: [])
        }
        return try await EnvironmentResource(equirectangular: image, withName: name)
    }

    // MARK: Components

    /// Attaches the video light to the world root. Children with an
    /// `ImageBasedLightReceiverComponent` pointing here are lit by it.
    static func attachWorldLight(_ resource: EnvironmentResource, to world: Entity, intensityExponent: Float) {
        world.components.set(ImageBasedLightComponent(source: .single(resource),
                                                      intensityExponent: intensityExponent))
    }

    /// Gives `creature` its own blendable light and wires every model node to receive from it.
    static func attachCreatureLight(video: EnvironmentResource,
                                    neutral: EnvironmentResource,
                                    intensityExponent: Float,
                                    to creature: Entity) {
        creature.components.set(ImageBasedLightComponent(source: .blend(video, neutral, 0),
                                                         intensityExponent: intensityExponent))
        creature.components.set(LightBlendComponent(video: video,
                                                    neutral: neutral,
                                                    intensityExponent: intensityExponent))
        setReceiver(on: creature, lightSource: creature)
    }

    /// Recursively point every `ModelEntity` at `lightSource`.
    static func setReceiver(on entity: Entity, lightSource: Entity) {
        if entity.components.has(ModelComponent.self) {
            entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: lightSource))
        }
        for child in entity.children {
            setReceiver(on: child, lightSource: lightSource)
        }
    }

    // MARK: Image helpers

    private static func pad180To360(_ frame: CGImage) throws -> CGImage {
        let width = frame.width * 2
        let height = frame.height
        let average = averageColor(of: frame)
        return try renderImage(size: CGSize(width: width, height: height)) { ctx in
            ctx.setFillColor(average)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.draw(frame, in: CGRect(x: frame.width / 2, y: 0, width: frame.width, height: height))
        }
    }

    private static func averageColor(of image: CGImage) -> CGColor {
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        if let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                               space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return CGColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                       blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }

    private static func renderImage(size: CGSize, draw: (CGContext) throws -> Void) throws -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw LightingError.contextFailed
        }
        try draw(ctx)
        guard let image = ctx.makeImage() else { throw LightingError.contextFailed }
        return image
    }

    enum LightingError: Error { case contextFailed, gradientFailed }
}

/// Keeps the two probes alive and remembers the exponent so `CreatureSystem` can re-blend them.
struct LightBlendComponent: Component {
    var video: EnvironmentResource
    var neutral: EnvironmentResource
    var intensityExponent: Float
    /// 0 = fully video-lit, 1 = fully neutral. Written by `CreatureSystem`.
    var blend: Float = 0
}
