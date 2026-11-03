import RealityKit
import UIKit
import simd

/// Primitive stand-ins so the app runs before real USDZ assets exist. Each one faces +Z
/// (toward the user), has its feet/belly at y = 0, and exposes "head" and "tail" pivots that
/// `CreatureSystem` animates. Semi-gloss materials make the lighting hand-off easy to see.
enum PlaceholderCreatures {

    static func make(_ kind: PlaceholderKind) -> Entity {
        switch kind {
        case .narwhal: return narwhal()
        case .mermaid: return mermaid()
        case .unicorn: return unicorn()
        case .puppy:   return puppy()
        }
    }

    // MARK: Narwhal — ~1.5 m body, 0.7 m tusk, nose at +Z

    private static func narwhal() -> Entity {
        let root = Entity()
        let skin = SimpleMaterial(color: UIColor(red: 0.56, green: 0.60, blue: 0.66, alpha: 1), roughness: 0.3, isMetallic: false)
        let belly = SimpleMaterial(color: UIColor(white: 0.88, alpha: 1), roughness: 0.4, isMetallic: false)
        let ivory = SimpleMaterial(color: UIColor(red: 0.93, green: 0.90, blue: 0.80, alpha: 1), roughness: 0.25, isMetallic: false)

        let body = ModelEntity(mesh: .generateSphere(radius: 1), materials: [skin])
        body.scale = [0.22, 0.22, 0.75]
        root.addChild(body)

        let underside = ModelEntity(mesh: .generateSphere(radius: 1), materials: [belly])
        underside.scale = [0.19, 0.15, 0.6]
        underside.position = [0, -0.07, 0.05]
        root.addChild(underside)

        let head = Entity(); head.name = "head"; head.position = [0, 0.02, 0.72]
        let tusk = ModelEntity(mesh: .generateCone(height: 0.7, radius: 0.03), materials: [ivory])
        tusk.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])   // apex toward +Z
        tusk.position = [0, 0, 0.35]
        head.addChild(tusk)
        root.addChild(head)

        let tail = Entity(); tail.name = "tail"; tail.position = [0, 0, -0.78]
        let flukes = ModelEntity(mesh: .generateBox(size: [0.5, 0.03, 0.22], cornerRadius: 0.1), materials: [skin])
        flukes.position = [0, 0, -0.1]
        tail.addChild(flukes)
        root.addChild(tail)

        for side: Float in [-1, 1] {
            let fin = ModelEntity(mesh: .generateBox(size: [0.22, 0.03, 0.14], cornerRadius: 0.06), materials: [skin])
            fin.position = [side * 0.26, -0.05, 0.25]
            fin.orientation = simd_quatf(angle: side * 0.35, axis: [0, 0, 1])
            root.addChild(fin)
        }
        return root
    }

    // MARK: Mermaid — ~1.6 m tall, upright, tail curls down

    private static func mermaid() -> Entity {
        let root = Entity()
        let scales = SimpleMaterial(color: UIColor(red: 0.10, green: 0.65, blue: 0.62, alpha: 1), roughness: 0.2, isMetallic: true)
        let skinTone = SimpleMaterial(color: UIColor(red: 0.80, green: 0.60, blue: 0.48, alpha: 1), roughness: 0.6, isMetallic: false)
        let hair = SimpleMaterial(color: UIColor(red: 0.85, green: 0.30, blue: 0.35, alpha: 1), roughness: 0.5, isMetallic: false)

        let tailPivot = Entity(); tailPivot.name = "tail"; tailPivot.position = [0, 0.75, 0]
        let tailBody = ModelEntity(mesh: .generateSphere(radius: 1), materials: [scales])
        tailBody.scale = [0.17, 0.42, 0.14]
        tailBody.position = [0, -0.35, 0]
        tailPivot.addChild(tailBody)
        let fluke = ModelEntity(mesh: .generateBox(size: [0.42, 0.03, 0.18], cornerRadius: 0.08), materials: [scales])
        fluke.position = [0, -0.78, 0.05]
        fluke.orientation = simd_quatf(angle: 0.5, axis: [1, 0, 0])
        tailPivot.addChild(fluke)
        root.addChild(tailPivot)

        let torso = ModelEntity(mesh: .generateSphere(radius: 1), materials: [skinTone])
        torso.scale = [0.17, 0.26, 0.12]
        torso.position = [0, 1.02, 0]
        root.addChild(torso)

        let head = Entity(); head.name = "head"; head.position = [0, 1.38, 0]
        let face = ModelEntity(mesh: .generateSphere(radius: 0.11), materials: [skinTone])
        head.addChild(face)
        let mane = ModelEntity(mesh: .generateSphere(radius: 1), materials: [hair])
        mane.scale = [0.14, 0.2, 0.13]
        mane.position = [0, 0.0, -0.05]
        head.addChild(mane)
        root.addChild(head)

        for side: Float in [-1, 1] {
            let arm = ModelEntity(mesh: .generateCylinder(height: 0.45, radius: 0.035), materials: [skinTone])
            arm.position = [side * 0.21, 1.02, 0]
            arm.orientation = simd_quatf(angle: side * 0.5, axis: [0, 0, 1])
            root.addChild(arm)
        }
        return root
    }

    // MARK: Unicorn — ~1.6 m at the horn tip, hooves at y = 0

    private static func unicorn() -> Entity {
        let root = Entity()
        let coat = SimpleMaterial(color: UIColor(white: 0.97, alpha: 1), roughness: 0.45, isMetallic: false)
        let gold = SimpleMaterial(color: UIColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1), roughness: 0.15, isMetallic: true)
        let mane = SimpleMaterial(color: UIColor(red: 0.80, green: 0.55, blue: 0.95, alpha: 1), roughness: 0.6, isMetallic: false)

        let body = ModelEntity(mesh: .generateSphere(radius: 1), materials: [coat])
        body.scale = [0.28, 0.3, 0.55]
        body.position = [0, 0.85, 0]
        root.addChild(body)

        for (x, z) in [(-0.16, 0.3), (0.16, 0.3), (-0.16, -0.3), (0.16, -0.3)] as [(Float, Float)] {
            let leg = ModelEntity(mesh: .generateCylinder(height: 0.7, radius: 0.05), materials: [coat])
            leg.position = [x, 0.35, z]
            root.addChild(leg)
        }

        let neck = ModelEntity(mesh: .generateCylinder(height: 0.5, radius: 0.09), materials: [coat])
        neck.position = [0, 1.15, 0.5]
        neck.orientation = simd_quatf(angle: -0.6, axis: [1, 0, 0])
        root.addChild(neck)

        let head = Entity(); head.name = "head"; head.position = [0, 1.4, 0.72]
        let skull = ModelEntity(mesh: .generateSphere(radius: 1), materials: [coat])
        skull.scale = [0.11, 0.13, 0.24]
        head.addChild(skull)
        let horn = ModelEntity(mesh: .generateCone(height: 0.32, radius: 0.03), materials: [gold])
        horn.position = [0, 0.2, 0.05]
        horn.orientation = simd_quatf(angle: 0.35, axis: [1, 0, 0])
        head.addChild(horn)
        let forelock = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [mane])
        forelock.position = [0, 0.1, -0.1]
        head.addChild(forelock)
        root.addChild(head)

        let crest = ModelEntity(mesh: .generateBox(size: [0.05, 0.22, 0.45], cornerRadius: 0.02), materials: [mane])
        crest.position = [0, 1.28, 0.3]
        crest.orientation = simd_quatf(angle: -0.6, axis: [1, 0, 0])
        root.addChild(crest)

        let tail = Entity(); tail.name = "tail"; tail.position = [0, 0.95, -0.55]
        let tailHair = ModelEntity(mesh: .generateBox(size: [0.08, 0.55, 0.08], cornerRadius: 0.04), materials: [mane])
        tailHair.position = [0, -0.25, -0.05]
        tail.addChild(tailHair)
        root.addChild(tail)
        return root
    }

    // MARK: Puppy — ~0.45 m long, paws at y = 0

    private static func puppy() -> Entity {
        let root = Entity()
        let fur = SimpleMaterial(color: UIColor(red: 0.85, green: 0.65, blue: 0.38, alpha: 1), roughness: 0.7, isMetallic: false)
        let dark = SimpleMaterial(color: UIColor(white: 0.1, alpha: 1), roughness: 0.3, isMetallic: false)
        let earFur = SimpleMaterial(color: UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1), roughness: 0.75, isMetallic: false)

        let body = ModelEntity(mesh: .generateSphere(radius: 1), materials: [fur])
        body.scale = [0.14, 0.13, 0.2]
        body.position = [0, 0.22, 0]
        root.addChild(body)

        for (x, z) in [(-0.08, 0.12), (0.08, 0.12), (-0.08, -0.12), (0.08, -0.12)] as [(Float, Float)] {
            let leg = ModelEntity(mesh: .generateCylinder(height: 0.2, radius: 0.03), materials: [fur])
            leg.position = [x, 0.1, z]
            root.addChild(leg)
        }

        let head = Entity(); head.name = "head"; head.position = [0, 0.36, 0.2]
        let skull = ModelEntity(mesh: .generateSphere(radius: 0.12), materials: [fur])
        head.addChild(skull)
        let snout = ModelEntity(mesh: .generateSphere(radius: 1), materials: [fur])
        snout.scale = [0.06, 0.05, 0.08]
        snout.position = [0, -0.03, 0.11]
        head.addChild(snout)
        let nose = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [dark])
        nose.position = [0, -0.01, 0.19]
        head.addChild(nose)
        for side: Float in [-1, 1] {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.018), materials: [dark])
            eye.position = [side * 0.05, 0.03, 0.1]
            head.addChild(eye)
            let ear = ModelEntity(mesh: .generateBox(size: [0.04, 0.14, 0.08], cornerRadius: 0.02), materials: [earFur])
            ear.position = [side * 0.12, -0.02, -0.02]
            ear.orientation = simd_quatf(angle: side * 0.25, axis: [0, 0, 1])
            head.addChild(ear)
        }
        root.addChild(head)

        let tail = Entity(); tail.name = "tail"; tail.position = [0, 0.3, -0.19]
        let tailStub = ModelEntity(mesh: .generateCylinder(height: 0.16, radius: 0.018), materials: [fur])
        tailStub.position = [0, 0.05, -0.05]
        tailStub.orientation = simd_quatf(angle: 0.8, axis: [1, 0, 0])
        tail.addChild(tailStub)
        root.addChild(tail)
        return root
    }
}
