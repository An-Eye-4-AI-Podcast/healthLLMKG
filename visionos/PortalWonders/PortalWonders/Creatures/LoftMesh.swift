import RealityKit
import simd

/// One cross-section of a lofted body: where it sits on the spine and how fat it is there.
struct LoftStation {
    var center: SIMD3<Float>
    /// Half-width along the section's "right" axis and "up" axis.
    var rx: Float
    var ry: Float

    init(_ center: SIMD3<Float>, _ rx: Float, _ ry: Float? = nil) {
        self.center = center
        self.rx = rx
        self.ry = ry ?? rx
    }
}

/// Sweeps elliptical rings along a spine and skins them into a smooth, capped tube.
/// This is how every stand-in creature gets a body that reads as flesh rather than beads.
enum LoftMesh {

    static func make(_ stations: [LoftStation], segments: Int = 24) throws -> MeshResource {
        precondition(stations.count >= 2, "A loft needs at least two stations")
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // Ring vertices.
        for (j, s) in stations.enumerated() {
            let tangent = spineTangent(stations, at: j)
            let (right, up) = frame(for: tangent)
            for i in 0..<segments {
                let theta = Float(i) / Float(segments) * 2 * .pi
                positions.append(s.center + right * (s.rx * cos(theta)) + up * (s.ry * sin(theta)))
            }
        }
        // Side quads, outward-facing.
        let segs = UInt32(segments)
        for j in 0..<(stations.count - 1) {
            let ring0 = UInt32(j) * segs
            let ring1 = ring0 + segs
            for i in 0..<segs {
                let a = ring0 + i
                let b = ring0 + (i + 1) % segs
                let c = ring1 + i
                let d = ring1 + (i + 1) % segs
                indices += [a, b, c, b, d, c]
            }
        }
        // Caps.
        let startCenter = UInt32(positions.count)
        positions.append(stations.first!.center)
        for i in 0..<segs {
            indices += [startCenter, (i + 1) % segs, i]
        }
        let endCenter = UInt32(positions.count)
        positions.append(stations.last!.center)
        let lastRing = UInt32(stations.count - 1) * segs
        for i in 0..<segs {
            indices += [endCenter, lastRing + i, lastRing + (i + 1) % segs]
        }

        let normals = smoothNormals(positions: positions, indices: indices)
        var descriptor = MeshDescriptor(name: "loft")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    // MARK: Helpers

    private static func spineTangent(_ s: [LoftStation], at j: Int) -> SIMD3<Float> {
        let prev = s[max(j - 1, 0)].center
        let next = s[min(j + 1, s.count - 1)].center
        let t = next - prev
        return simd_length(t) > 1e-6 ? simd_normalize(t) : [0, 0, 1]
    }

    /// Right-handed (right, up, tangent) frame; falls back to +Z as "up" for vertical spines.
    private static func frame(for tangent: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        var worldUp: SIMD3<Float> = [0, 1, 0]
        if abs(simd_dot(tangent, worldUp)) > 0.99 { worldUp = [0, 0, 1] }
        let right = simd_normalize(simd_cross(worldUp, tangent))
        let up = simd_cross(tangent, right)
        return (right, up)
    }

    private static func smoothNormals(positions: [SIMD3<Float>], indices: [UInt32]) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            let n = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            normals[a] += n; normals[b] += n; normals[c] += n
            i += 3
        }
        return normals.map { simd_length($0) > 1e-8 ? simd_normalize($0) : [0, 1, 0] }
    }
}
