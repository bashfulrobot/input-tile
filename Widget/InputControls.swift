import AppIntents
import SwiftUI
import WidgetKit

// MARK: Intents

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
    private static let panelURL = URL(string: "inputtile://panel")!

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: InputStateProvider()) { state in
            ControlWidgetButton(action: OpenURLIntent(Self.panelURL)) {
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
