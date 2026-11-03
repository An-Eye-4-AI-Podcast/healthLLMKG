import SwiftUI
import RealityKit

/// The mixed-immersion space holding the portal. One `PortalScene` per open environment.
struct PortalImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var scene: PortalScene?
    @State private var tracker = UserTracker()
    @State private var missingAssets: [String] = []

    private let hudAttachmentID = "hud"

    var body: some View {
        RealityView { content, attachments in
            let scene = PortalScene(environment: appModel.selectedEnvironment)
            await scene.build(ambience: appModel.ambienceEnabled)
            content.add(scene.root)

            if let hud = attachments.entity(for: hudAttachmentID) {
                let cfg = scene.config
                // Beside the portal, at the viewer's eye line, angled slightly inward.
                hud.position = cfg.portalPosition + [cfg.portalSize.x / 2 + 0.42, 0.15, 0.1]
                hud.orientation = simd_quatf(angle: -0.25, axis: [0, 1, 0])
                scene.root.addChild(hud)
            }
            self.scene = scene
            self.missingAssets = scene.missingAssets
        } attachments: {
            Attachment(id: hudAttachmentID) {
                PortalHUD(environment: appModel.selectedEnvironment,
                          missingAssets: missingAssets,
                          handTrackingError: tracker.lastError,
                          onSummon: { scene?.summonAll() },
                          onClose: { Task { await dismissImmersiveSpace() } })
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in scene?.handleTap(on: value.entity) }
        )
        .task {
            await tracker.start(trackHands: appModel.handTrackingEnabled)
        }
        .task {
            // Follow the footage: re-sample the IBL every N seconds.
            let interval = appModel.lightingRefreshSeconds
            guard interval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                await scene?.refreshLighting()
            }
        }
        .onDisappear {
            scene?.tearDown()
            scene = nil
            tracker.stop()
            appModel.immersiveState = .closed
        }
    }
}

/// A small glass label under the portal: hint, controls, and any asset warnings.
private struct PortalHUD: View {
    let environment: WonderEnvironment
    let missingAssets: [String]
    let handTrackingError: String?
    let onSummon: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(environment.title).font(.title3.bold())
            Text(environment.hint).font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Call them over", systemImage: "hand.wave", action: onSummon)
                Button("Close portal", systemImage: "xmark", action: onClose)
            }
            .font(.callout)
            if let handTrackingError {
                Text(handTrackingError).font(.caption2).foregroundStyle(.orange)
            }
            if !missingAssets.isEmpty {
                Text("Using stand-ins for: " + missingAssets.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: 420)
            }
        }
        .padding(18)
        .glassBackgroundEffect()
    }
}
