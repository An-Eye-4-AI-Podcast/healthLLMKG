import SwiftUI

/// The launch window: three cards, one portal at a time. Mirrors the Encounter Dinosaurs lobby.
struct EnvironmentPickerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        @Bindable var appModel = appModel
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("Portal Wonders")
                    .font(.extraLargeTitle2)
                Text("Open a window into another world. Look, don't leap.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                ForEach(WonderEnvironment.allCases) { environment in
                    EnvironmentCard(environment: environment,
                                    isActive: appModel.immersiveState == .open && appModel.selectedEnvironment == environment,
                                    isBusy: appModel.immersiveState == .inTransition) {
                        Task { await open(environment) }
                    }
                }
            }

            HStack(spacing: 24) {
                Toggle("Hand tracking", isOn: $appModel.handTrackingEnabled)
                Toggle("Ambience", isOn: $appModel.ambienceEnabled)
                if appModel.immersiveState == .open {
                    Button("Close portal", systemImage: "xmark.circle") {
                        Task { await close() }
                    }
                }
            }
            .toggleStyle(.button)
            .font(.callout)
        }
        .padding(40)
        .glassBackgroundEffect()
    }

    private func open(_ environment: WonderEnvironment) async {
        if appModel.immersiveState == .open {
            await close()
        }
        appModel.selectedEnvironment = environment
        appModel.immersiveState = .inTransition
        switch await openImmersiveSpace(id: SceneID.portal) {
        case .opened:
            appModel.immersiveState = .open
        case .userCancelled, .error:
            appModel.immersiveState = .closed
        @unknown default:
            appModel.immersiveState = .closed
        }
    }

    private func close() async {
        appModel.immersiveState = .inTransition
        await dismissImmersiveSpace()
        appModel.immersiveState = .closed
    }
}

private struct EnvironmentCard: View {
    let environment: WonderEnvironment
    let isActive: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: environment.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Text(environment.title)
                    .font(.title2.bold())
                Text(environment.tagline)
                    .font(.callout)
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Label(isActive ? "Open" : "Open portal", systemImage: isActive ? "checkmark.circle.fill" : "arrow.up.forward.circle")
                    .font(.headline)
                    .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(width: 300, height: 300, alignment: .topLeading)
            .background(
                LinearGradient(colors: environment.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(isActive ? 0.9 : 0.15), lineWidth: isActive ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .hoverEffect()
    }
}

#Preview(windowStyle: .plain) {
    EnvironmentPickerView()
        .environment(AppModel())
}
