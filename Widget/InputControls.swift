import AppIntents
import AppKit
import SwiftUI
import WidgetKit

// MARK: Intents

/// Opens the Sound-style input panel in the host app. The system `OpenURLIntent` is not in this
/// app's intent metadata, so a tap on a control using it does nothing.
struct OpenInputPanelIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Input Panel"
    static let description = IntentDescription("Opens the input volume and device list.")

    func perform() async throws -> some IntentResult {
        // Resolve the host app by bundle ID and hand it the URL directly, so another app that
        // registers the same URL scheme cannot receive the tap.
        let workspace = NSWorkspace.shared
        guard let host = workspace.urlForApplication(withBundleIdentifier: "com.bashfulrobot.InputTile") else {
            return .result()
        }
        try await workspace.open(
            [URL(string: "inputtile://panel")!],
            withApplicationAt: host,
            configuration: NSWorkspace.OpenConfiguration()
        )
        return .result()
    }
}

/// Sets the default input muted or unmuted.
struct SetInputMuteIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Mute Input"

    @Parameter(title: "Muted")
    var value: Bool

    func perform() async throws -> some IntentResult {
        AudioInput.setMuted(value)
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}

// MARK: Value provider

struct InputState {
    var deviceName: String
    var isMuted: Bool
}

struct InputStateProvider: ControlValueProvider {
    var previewValue: InputState { InputState(deviceName: "MacBook Pro Microphone", isMuted: false) }

    func currentValue() async throws -> InputState {
        InputState(
            // The medium tile fits about 10 characters, so drop the word every mic name shares.
            deviceName: AudioInput.defaultInput()?.name
                .replacingOccurrences(of: " Microphone", with: "") ?? "No Input",
            isMuted: AudioInput.isMuted() ?? false
        )
    }
}

// MARK: Tiles

/// Medium tile: mic icon, "Input" title, current device as subtitle.
/// A tap opens the Sound-style input panel through the host app's `inputtile://panel` URL.
struct InputDeviceControl: ControlWidget {
    static let kind = "com.bashfulrobot.InputTile.device"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: InputStateProvider()) { state in
            ControlWidgetButton(action: OpenInputPanelIntent()) {
                Label("Input", systemImage: "mic.fill")
                Text(state.deviceName)
            }
        }
        .displayName("Input")
        .description("Shows the current sound input. Tap to open the input volume and device list.")
    }
}

/// Toggle tile: tap mutes or unmutes the current input.
struct InputMuteControl: ControlWidget {
    static let kind = "com.bashfulrobot.InputTile.mute"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: InputStateProvider()) { state in
            ControlWidgetToggle(
                isOn: state.isMuted,
                action: SetInputMuteIntent()
            ) {
                Label("Input", systemImage: state.isMuted ? "mic.slash.fill" : "mic.fill")
            } valueLabel: { muted in
                Text(muted ? "Muted" : state.deviceName)
            }
        }
        .displayName("Input Mute")
        .description("Mutes or unmutes the current sound input.")
    }
}

@main
struct InputTileBundle: WidgetBundle {
    var body: some Widget {
        InputDeviceControl()
        InputMuteControl()
    }
}
