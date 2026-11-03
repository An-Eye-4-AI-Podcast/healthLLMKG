import RealityKit
import AVFoundation
import simd

/// Owns the looping player so the looper is not deallocated mid-playback.
final class VideoPlayback {
    let player: AVQueuePlayer
    let url: URL
    private let looper: AVPlayerLooper

    init(url: URL) {
        self.url = url
        let item = AVPlayerItem(url: url)
        player = AVQueuePlayer()
        player.isMuted = false
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play()  { player.play() }
    func pause() { player.pause() }
}

/// Builds the inside-out sphere (or hemisphere) that the equirectangular video is projected onto.
///
/// The dome is centred on the user's head so the video reads as "infinitely far away" through the
/// portal, exactly like the rendered backdrops in Encounter Dinosaurs.
enum ImmersiveVideoDome {

    /// Inward-facing sphere. `θ = 0` points down −Z (forward), `+X` is the viewer's right.
    static func makeMesh(projection: VideoProjection,
                         radius: Float,
                         segments: Int = 96,
                         rings: Int = 48) throws -> MeshResource {
        let (lonMin, lonMax): (Float, Float)
        switch projection {
        case .equirectangular360: (lonMin, lonMax) = (-.pi, .pi)
        case .equirectangular180: (lonMin, lonMax) = (-.pi / 2, .pi / 2)
        }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity((rings + 1) * (segments + 1))

        for j in 0...rings {
            let v = Float(j) / Float(rings)         // 0 = bottom, 1 = top (RealityKit UV origin is bottom-left)
            let lat = (v - 0.5) * .pi               // −π/2 … π/2
            for i in 0...segments {
                let u = Float(i) / Float(segments)
                let lon = lonMin + u * (lonMax - lonMin)
                let p = SIMD3<Float>(cos(lat) * sin(lon), sin(lat), -cos(lat) * cos(lon)) * radius
                positions.append(p)
                normals.append(-simd_normalize(p))  // faces inward
                uvs.append([u, v])
            }
        }

        // Counter-clockwise as seen from inside the sphere.
        var indices: [UInt32] = []
        indices.reserveCapacity(rings * segments * 6)
        let stride = UInt32(segments + 1)
        for j in 0..<rings {
            for i in 0..<segments {
                let a = UInt32(j) * stride + UInt32(i)
                let b = a + 1
                let c = a + stride
                let d = c + 1
                indices += [a, b, c, b, d, c]
            }
        }

        var descriptor = MeshDescriptor(name: "videoDome-\(projection.rawValue)")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// Dome entity wearing a `VideoMaterial`. Unlit by design — the video *is* the light.
    static func makeEntity(playback: VideoPlayback,
                           projection: VideoProjection,
                           radius: Float = 40) throws -> ModelEntity {
        let mesh = try makeMesh(projection: projection, radius: radius)
        let material = VideoMaterial(avPlayer: playback.player)
        let dome = ModelEntity(mesh: mesh, materials: [material])
        dome.name = "videoDome"
        return dome
    }

    /// Dome wearing a still equirectangular image instead of video. Always a full 360° sphere.
    static func makeStillEntity(texture: TextureResource, radius: Float = 40) throws -> ModelEntity {
        let mesh = try makeMesh(projection: .equirectangular360, radius: radius)
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        let dome = ModelEntity(mesh: mesh, materials: [material])
        dome.name = "panoramaDome"
        return dome
    }

    /// Solid colour sphere slightly larger than the dome. Fills the back hemisphere behind a 180°
    /// video so the portal never shows raw passthrough where the footage ends.
    static func makeBackdrop(color: UIColor, radius: Float = 45) throws -> ModelEntity {
        let mesh = try makeMesh(projection: .equirectangular360, radius: radius, segments: 32, rings: 16)
        var material = UnlitMaterial(color: color)
        material.blending = .opaque
        let backdrop = ModelEntity(mesh: mesh, materials: [material])
        backdrop.name = "videoBackdrop"
        return backdrop
    }
}
