import CoreAudio
import SwiftUI

/// Host app. WidgetKit only registers the controls while their containing app is installed.
/// The window lists input devices so the tiles can be checked without Control Center.
@main
struct InputTileApp: App {
    var body: some Scene {
        Window("Input Tile", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var devices = AudioInput.devices()
    @State private var current = AudioInput.defaultInputID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sound input")
                .font(.headline)
            ForEach(devices) { device in
                Button {
                    AudioInput.setDefaultInput(device)
                    current = AudioInput.defaultInputID()
                } label: {
                    HStack {
                        Image(systemName: device.id == current ? "checkmark.circle.fill" : "circle")
                        Text(device.name)
                    }
                }
                .buttonStyle(.plain)
            }
            Text("Add the Input Device and Input Mute tiles from System Settings > Control Center, or Edit Controls.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(20)
        .onAppear {
            devices = AudioInput.devices()
            current = AudioInput.defaultInputID()
        }
    }
}
