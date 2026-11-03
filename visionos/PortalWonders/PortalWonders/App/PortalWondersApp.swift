import SwiftUI
import RealityKit

/// Portal Wonders — three "look, don't enter" portals in the spirit of Encounter Dinosaurs.
///
/// Scenes:
///   • A plain window (`EnvironmentPickerView`) where the user picks a world.
///   • A mixed-immersion `ImmersiveSpace` (`PortalImmersiveView`) that cuts a portal
///     into the room, plays a 180°/360° video behind it, and lets creatures poke
///     through the portal plane into the user's space.
@main
struct PortalWondersApp: App {
    @State private var appModel = AppModel()

    init() {
        // ECS registration must happen before any RealityView is created.
        CreatureComponent.registerComponent()
        LightBlendComponent.registerComponent()
        VoiceComponent.registerComponent()
        PortalRippleComponent.registerComponent()
        TrailComponent.registerComponent()
        CreatureSystem.registerSystem()
    }

    var body: some Scene {
        WindowGroup(id: SceneID.picker) {
            EnvironmentPickerView()
                .environment(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1100, height: 640)

        ImmersiveSpace(id: SceneID.portal) {
            PortalImmersiveView()
                .environment(appModel)
        }
        // `.mixed` keeps passthrough on: the room stays, the portal is a window into the world.
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

enum SceneID {
    static let picker = "picker"
    static let portal = "portal"
}
