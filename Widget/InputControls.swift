import AppIntents
import SwiftUI
import WidgetKit

// MARK: Intents

/// Switches the default input to the next device and refreshes both tiles.
struct CycleInputDeviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Input Device"
    static let description = IntentDescription("Switches the Mac's sound input to the next available device.")

    func perform() async throws -> some IntentResult {
        AudioInput.cycleDefaultInput()
        ControlCenter.shared.reloadAllControls()
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
            deviceName: AudioInput.defaultInput()?.name ?? "No Input",
            isMuted: AudioInput.isMuted() ?? false
        )
    }
}

// MARK: Tiles

/// Medium tile: mic icon, "Input" title, current device as subtitle. A tap cycles to the next device.
struct InputDeviceControl: ControlWidget {
    static let kind = "com.bashfulrobot.InputTile.device"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: InputStateProvider()) { state in
            ControlWidgetButton(action: CycleInputDeviceIntent()) {
                Label("Input", systemImage: "mic.fill")
                Text(state.deviceName)
            }
        }
        .displayName("Input Device")
        .description("Shows the current sound input and switches to the next device on tap.")
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
