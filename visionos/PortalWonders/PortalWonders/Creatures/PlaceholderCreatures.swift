import RealityKit
import UIKit
import simd

/// Procedural stand-ins built from lofted bodies so the app looks alive before real USDZ assets
/// arrive. Every creature faces +Z, stands with feet (or belly) at y = 0, and exposes pivots
/// named `head`, `tail`, and `legFL/legFR/legBL/legBR` that `CreatureSystem` animates.
enum PlaceholderCreatures {

    static func make(_ kind: PlaceholderKind) -> Entity {
        switch kind {
        case .narwhal: return narwhal()
        case .mermaid: return mermaid()
        case .unicorn: return unicorn()
        case .puppy:   return puppy()
        }
    }

    // MARK: - Narwhal (1.7 m body + 0.75 m tusk)

    private static func narwhal() -> Entity {
        let root = Entity()
        let skin = pbr(0.52, 0.57, 0.64, roughness: 0.35, clearcoat: 0.5)
        let belly = pbr(0.86, 0.88, 0.90, roughness: 0.45)
        let ivory = pbr(0.93, 0.89, 0.78, roughness: 0.25, clearcoat: 0.8)

        // Body: a torpedo that thickens behind the head and tapers to the tail stock.
        root.addChild(part([
            LoftStation([0, 0.02, -0.92], 0.015),
            LoftStation([0, 0.01, -0.70], 0.07, 0.06),
            LoftStation([0, 0.00, -0.42], 0.15, 0.14),
            LoftStation([0, 0.00, -0.12], 0.22, 0.20),
            LoftStation([0, 0.00,  0.20], 0.23, 0.21),
            LoftStation([0, 0.01,  0.48], 0.19, 0.18),
            LoftStation([0, 0.02,  0.68], 0.12, 0.12),
            LoftStation([0, 0.02,  0.80], 0.035),
        ], skin))
        // Pale underside, nested just inside the body so the seam reads as countershading.
        root.addChild(part([
            LoftStation([0, -0.06, -0.55], 0.06, 0.05),
            LoftStation([0, -0.08, -0.15], 0.16, 0.13),
            LoftStation([0, -0.08,  0.25], 0.17, 0.13),
            LoftStation([0, -0.06,  0.55], 0.10, 0.09),
            LoftStation([0, -0.03,  0.70], 0.02),
        ], belly))

        // Head pivot carries the tusk so a nod moves it too.
        let head = pivot("head", at: [0, 0.0, 0.78])
        head.addChild(part([
            LoftStation([0, 0.02, 0.00], 0.03),
            LoftStation([0, 0.02, 0.30], 0.022),
            LoftStation([0, 0.02, 0.60], 0.012),
            LoftStation([0, 0.02, 0.76], 0.003),
        ], ivory))
        head.addChild(eye(at: [-0.16, 0.05, -0.20]))
        head.addChild(eye(at: [ 0.16, 0.05, -0.20]))
        root.addChild(head)

        // Tail pivot with a horizontal fluke.
        let tail = pivot("tail", at: [0, 0.02, -0.86])
        tail.addChild(part([
            LoftStation([-0.40, 0.0, -0.12], 0.03, 0.008),
            LoftStation([-0.22, 0.0, -0.08], 0.09, 0.012),
            LoftStation([ 0.00, 0.0, -0.02], 0.11, 0.018),
            LoftStation([ 0.22, 0.0, -0.08], 0.09, 0.012),
            LoftStation([ 0.40, 0.0, -0.12], 0.03, 0.008),
        ], skin))
        root.addChild(tail)

        // Pectoral fins swept back.
        for side: Float in [-1, 1] {
            root.addChild(part([
                LoftStation([side * 0.20, -0.06, 0.25], 0.07, 0.015),
                LoftStation([side * 0.36, -0.10, 0.12], 0.06, 0.012),
                LoftStation([side * 0.46, -0.13, 0.02], 0.02, 0.006),
            ], skin))
        }
        return root
    }

    // MARK: - Mermaid (1.7 m, upright)

    private static func mermaid() -> Entity {
        let root = Entity()
        let scales = pbr(0.10, 0.62, 0.60, roughness: 0.22, metallic: 0.35, clearcoat: 1.0)
        let skin = pbr(0.80, 0.60, 0.48, roughness: 0.55)
        let hair = pbr(0.78, 0.26, 0.32, roughness: 0.5)
        let shell = pbr(0.95, 0.55, 0.62, roughness: 0.35, clearcoat: 0.6)

        // Tail hangs from the hips; the pivot lets it sway side to side.
        let tail = pivot("tail", at: [0, 0.98, 0])
        tail.addChild(part([
            LoftStation([0,  0.00,  0.00], 0.18, 0.15),
            LoftStation([0, -0.22,  0.02], 0.16, 0.13),
            LoftStation([0, -0.45,  0.05], 0.13, 0.11),
            LoftStation([0, -0.66,  0.08], 0.09, 0.08),
            LoftStation([0, -0.84,  0.08], 0.05, 0.045),
            LoftStation([0, -0.93,  0.06], 0.03),
        ], scales))
        for side: Float in [-1, 1] {
            tail.addChild(part([
                LoftStation([0,           -0.93, 0.06], 0.03, 0.01),
                LoftStation([side * 0.14, -0.97, 0.12], 0.08, 0.012),
                LoftStation([side * 0.28, -0.98, 0.18], 0.06, 0.008),
                LoftStation([side * 0.34, -0.96, 0.22], 0.02, 0.005),
            ], scales))
        }
        root.addChild(tail)

        // Torso with a waist and shoulders.
        root.addChild(part([
            LoftStation([0, 0.96, 0.00], 0.18, 0.14),
            LoftStation([0, 1.12, 0.00], 0.14, 0.11),
            LoftStation([0, 1.28, 0.00], 0.17, 0.12),
            LoftStation([0, 1.40, 0.00], 0.20, 0.11),
            LoftStation([0, 1.46, 0.00], 0.07, 0.06),
        ], skin))
        root.addChild(part([   // bandeau
            LoftStation([-0.17, 1.30, 0.00], 0.05, 0.04),
            LoftStation([-0.08, 1.30, 0.10], 0.07, 0.05),
            LoftStation([ 0.00, 1.29, 0.12], 0.06, 0.045),
            LoftStation([ 0.08, 1.30, 0.10], 0.07, 0.05),
            LoftStation([ 0.17, 1.30, 0.00], 0.05, 0.04),
        ], shell))

        let head = pivot("head", at: [0, 1.47, 0])
        head.addChild(part([
            LoftStation([0, 0.00, 0.00], 0.05),
            LoftStation([0, 0.08, 0.01], 0.10, 0.11),
            LoftStation([0, 0.16, 0.01], 0.11, 0.11),
            LoftStation([0, 0.24, 0.00], 0.08, 0.08),
            LoftStation([0, 0.28, -0.01], 0.02),
        ], skin))
        head.addChild(part([   // hair swept back and down
            LoftStation([0, 0.28, -0.02], 0.09, 0.07),
            LoftStation([0, 0.22, -0.10], 0.13, 0.08),
            LoftStation([0, 0.05, -0.15], 0.14, 0.07),
            LoftStation([0, -0.15, -0.14], 0.11, 0.06),
            LoftStation([0, -0.32, -0.10], 0.06, 0.04),
            LoftStation([0, -0.40, -0.08], 0.01),
        ], hair))
        head.addChild(eye(at: [-0.04, 0.16, 0.10]))
        head.addChild(eye(at: [ 0.04, 0.16, 0.10]))
        root.addChild(head)

        for side: Float in [-1, 1] {
            root.addChild(part([
                LoftStation([side * 0.21, 1.40, 0.00], 0.045),
                LoftStation([side * 0.27, 1.22, 0.04], 0.04),
                LoftStation([side * 0.26, 1.04, 0.12], 0.035),
                LoftStation([side * 0.22, 0.98, 0.18], 0.02),
            ], skin))
        }
        return root
    }

    // MARK: - Unicorn (1.15 m at the withers, 1.8 m at the horn tip)

    private static func unicorn() -> Entity {
        let root = Entity()
        let coat = pbr(0.96, 0.95, 0.97, roughness: 0.5, clearcoat: 0.2)
        let mane = pbr(0.76, 0.52, 0.95, roughness: 0.6)
        let gold = pbr(1.0, 0.80, 0.32, roughness: 0.18, metallic: 0.9)
        let hoof = pbr(0.30, 0.28, 0.32, roughness: 0.3, clearcoat: 0.7)

        // Barrel.
        root.addChild(part([
            LoftStation([0, 0.90, -0.62], 0.10, 0.13),
            LoftStation([0, 0.90, -0.45], 0.24, 0.27),
            LoftStation([0, 0.90, -0.20], 0.27, 0.30),
            LoftStation([0, 0.90,  0.10], 0.26, 0.29),
            LoftStation([0, 0.92,  0.38], 0.23, 0.26),
            LoftStation([0, 0.98,  0.55], 0.14, 0.19),
            LoftStation([0, 1.02,  0.60], 0.04),
        ], coat))
        // Neck rising to the head.
        root.addChild(part([
            LoftStation([0, 0.98, 0.42], 0.14, 0.18),
            LoftStation([0, 1.20, 0.58], 0.11, 0.14),
            LoftStation([0, 1.40, 0.72], 0.09, 0.11),
            LoftStation([0, 1.48, 0.78], 0.06, 0.07),
        ], coat))
        root.addChild(part([   // mane along the crest
            LoftStation([0, 1.08, 0.36], 0.02, 0.06),
            LoftStation([0, 1.32, 0.52], 0.035, 0.13),
            LoftStation([0, 1.52, 0.68], 0.03, 0.12),
            LoftStation([0, 1.62, 0.78], 0.01, 0.05),
        ], mane))

        let head = pivot("head", at: [0, 1.48, 0.78])
        head.addChild(part([
            LoftStation([0,  0.04, -0.06], 0.05),
            LoftStation([0,  0.04,  0.02], 0.09, 0.11),
            LoftStation([0,  0.01,  0.12], 0.09, 0.11),
            LoftStation([0, -0.03,  0.22], 0.07, 0.08),
            LoftStation([0, -0.06,  0.30], 0.055, 0.06),
            LoftStation([0, -0.07,  0.34], 0.02),
        ], coat))
        head.addChild(part([   // horn
            LoftStation([0, 0.10, 0.04], 0.030),
            LoftStation([0, 0.22, 0.09], 0.020),
            LoftStation([0, 0.33, 0.14], 0.010),
            LoftStation([0, 0.40, 0.17], 0.002),
        ], gold))
        for side: Float in [-1, 1] {   // ears
            head.addChild(part([
                LoftStation([side * 0.05, 0.08, -0.02], 0.025, 0.015),
                LoftStation([side * 0.07, 0.17, -0.04], 0.018, 0.010),
                LoftStation([side * 0.08, 0.21, -0.05], 0.004),
            ], coat))
        }
        head.addChild(part([   // forelock
            LoftStation([0, 0.12, -0.02], 0.04, 0.02),
            LoftStation([0, 0.09,  0.08], 0.05, 0.02),
            LoftStation([0, 0.04,  0.15], 0.03, 0.015),
            LoftStation([0, 0.01,  0.18], 0.005),
        ], mane))
        head.addChild(eye(at: [-0.075, 0.03, 0.10], radius: 0.02))
        head.addChild(eye(at: [ 0.075, 0.03, 0.10], radius: 0.02))
        root.addChild(head)

        // Legs: pivots at hip/shoulder so they can swing.
        for (name, x, z) in [("legFL", -0.14, 0.32), ("legFR", 0.14, 0.32),
                             ("legBL", -0.15, -0.40), ("legBR", 0.15, -0.40)] as [(String, Float, Float)] {
            let leg = pivot(name, at: [x, 0.85, z])
            leg.addChild(part([
                LoftStation([0,  0.00, 0.0], 0.085, 0.10),
                LoftStation([0, -0.25, 0.0], 0.06, 0.065),
                LoftStation([0, -0.45, 0.0], 0.045, 0.05),
                LoftStation([0, -0.65, 0.0], 0.04, 0.045),
                LoftStation([0, -0.79, 0.0], 0.045, 0.05),
            ], coat))
            leg.addChild(part([
                LoftStation([0, -0.78, 0.0], 0.05, 0.055),
                LoftStation([0, -0.85, 0.01], 0.055, 0.06),
            ], hoof))
            root.addChild(leg)
        }

        let tail = pivot("tail", at: [0, 1.0, -0.62])
        tail.addChild(part([
            LoftStation([0,  0.00,  0.00], 0.05, 0.04),
            LoftStation([0, -0.12, -0.12], 0.07, 0.05),
            LoftStation([0, -0.38, -0.17], 0.06, 0.045),
            LoftStation([0, -0.60, -0.12], 0.04, 0.03),
            LoftStation([0, -0.70, -0.08], 0.01),
        ], mane))
        root.addChild(tail)
        return root
    }

    // MARK: - Puppy (0.5 m long, 0.4 m tall)

    private static func puppy() -> Entity {
        let root = Entity()
        let fur = pbr(0.86, 0.66, 0.40, roughness: 0.75)
        let earFur = pbr(0.60, 0.40, 0.22, roughness: 0.8)
        let pink = pbr(0.95, 0.55, 0.60, roughness: 0.4, clearcoat: 0.5)
        let nose = pbr(0.08, 0.07, 0.08, roughness: 0.25, clearcoat: 0.9)

        root.addChild(part([
            LoftStation([0, 0.22, -0.21], 0.09, 0.08),
            LoftStation([0, 0.22, -0.10], 0.13, 0.12),
            LoftStation([0, 0.23,  0.05], 0.13, 0.12),
            LoftStation([0, 0.24,  0.17], 0.10, 0.10),
            LoftStation([0, 0.26,  0.22], 0.04),
        ], fur))

        let head = pivot("head", at: [0, 0.34, 0.20])
        head.addChild(part([
            LoftStation([0,  0.00, -0.08], 0.06),
            LoftStation([0,  0.01,  0.00], 0.11, 0.105),
            LoftStation([0,  0.00,  0.08], 0.10, 0.095),
            LoftStation([0, -0.02,  0.12], 0.06, 0.055),
        ], fur))
        head.addChild(part([   // snout
            LoftStation([0, -0.03, 0.08], 0.05, 0.045),
            LoftStation([0, -0.035, 0.15], 0.042, 0.038),
            LoftStation([0, -0.03, 0.19], 0.025),
        ], fur))
        let noseTip = ModelEntity(mesh: .generateSphere(radius: 0.022), materials: [nose])
        noseTip.position = [0, -0.015, 0.20]
        head.addChild(noseTip)
        head.addChild(part([   // tongue
            LoftStation([0, -0.065, 0.12], 0.018, 0.005),
            LoftStation([0, -0.08,  0.17], 0.02, 0.005),
            LoftStation([0, -0.09,  0.19], 0.008, 0.003),
        ], pink))
        for side: Float in [-1, 1] {   // floppy ears
            head.addChild(part([
                LoftStation([side * 0.09,  0.06, -0.02], 0.02, 0.04),
                LoftStation([side * 0.13, -0.02, -0.01], 0.025, 0.055),
                LoftStation([side * 0.14, -0.11,  0.01], 0.02, 0.045),
                LoftStation([side * 0.14, -0.15,  0.02], 0.006, 0.015),
            ], earFur))
        }
        head.addChild(eye(at: [-0.05, 0.035, 0.085], radius: 0.017))
        head.addChild(eye(at: [ 0.05, 0.035, 0.085], radius: 0.017))
        root.addChild(head)

        for (name, x, z) in [("legFL", -0.075, 0.13), ("legFR", 0.075, 0.13),
                             ("legBL", -0.08, -0.13), ("legBR", 0.08, -0.13)] as [(String, Float, Float)] {
            let leg = pivot(name, at: [x, 0.2, z])
            leg.addChild(part([
                LoftStation([0,  0.00, 0.0], 0.045),
                LoftStation([0, -0.10, 0.0], 0.033),
                LoftStation([0, -0.17, 0.01], 0.034, 0.03),
                LoftStation([0, -0.20, 0.02], 0.038, 0.025),
            ], fur))
            root.addChild(leg)
        }

        let tail = pivot("tail", at: [0, 0.29, -0.21])
        tail.addChild(part([
            LoftStation([0, 0.00,  0.00], 0.022),
            LoftStation([0, 0.07, -0.06], 0.02),
            LoftStation([0, 0.14, -0.09], 0.014),
            LoftStation([0, 0.18, -0.10], 0.004),
        ], fur))
        root.addChild(tail)
        return root
    }

    // MARK: - Building blocks

    private static func part(_ stations: [LoftStation], _ material: Material) -> ModelEntity {
        let mesh = (try? LoftMesh.make(stations)) ?? MeshResource.generateSphere(radius: 0.05)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private static func pivot(_ name: String, at position: SIMD3<Float>) -> Entity {
        let e = Entity()
        e.name = name
        e.position = position
        return e
    }

    private static func eye(at position: SIMD3<Float>, radius: Float = 0.024) -> ModelEntity {
        let e = ModelEntity(mesh: .generateSphere(radius: radius),
                            materials: [pbr(0.05, 0.05, 0.06, roughness: 0.1, clearcoat: 1.0)])
        e.position = position
        return e
    }

    private static func pbr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat,
                            roughness: Float, metallic: Float = 0, clearcoat: Float = 0) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: r, green: g, blue: b, alpha: 1))
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: metallic)
        m.clearcoat = .init(floatLiteral: clearcoat)
        m.clearcoatRoughness = .init(floatLiteral: 0.2)
        return m
    }
}
