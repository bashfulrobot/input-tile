import AppKit
import Combine
import CoreAudio
import SwiftUI
import WidgetKit

/// Agent app that mimics the system Sound panel for inputs. The Control Center tile opens the panel
/// through the `inputtile://panel` URL, and the menu bar icon toggles it too.
@main
struct InputTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = InputModel()
    private var controller: PanelController?
    private var statusItem: NSStatusItem!
    private var iconWatcher: AnyCancellable?
    /// A launch by URL delivers `open` before `applicationDidFinishLaunching`, so remember the request.
    private var showWhenReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = PanelController(model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleFromStatusItem)
        iconWatcher = model.$isMuted.sink { [weak self] muted in
            let name = muted ? "mic.slash.fill" : "mic.fill"
            self?.statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Input")
        }

        // Dev flag for screenshots: ./build.sh show
        if showWhenReady || CommandLine.arguments.contains("--show") { controller?.show(anchor: nil) }
    }

    /// The Control Center tile opens `inputtile://panel`.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "inputtile" }) else { return }
        if let controller {
            controller.show(anchor: nil)
        } else {
            showWhenReady = true
        }
    }

    @objc private func toggleFromStatusItem() {
        guard let button = statusItem.button, let window = button.window else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        controller?.toggle(anchor: anchor)
    }
}

// MARK: Panel window

/// Borderless window that can take focus, so it closes when the user clicks elsewhere.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Shows `InputPanel` in a glass window. Placement: under the menu bar icon when opened from it,
/// otherwise in the top-right corner of the screen with the pointer, where Control Center opens.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let host: NSHostingView<InputPanel>
    private let glass = NSGlassEffectView()
    private var outsideClick: Any?

    init(model: InputModel) {
        host = NSHostingView(rootView: InputPanel(model: model))
        glass.cornerRadius = 22
        glass.contentView = host
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.contentView = glass
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
    }

    func toggle(anchor: NSRect?) {
        panel.isVisible ? hide() : show(anchor: anchor)
    }

    func show(anchor: NSRect?) {
        let size = host.fittingSize
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        var origin: NSPoint
        if let anchor {
            origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 6)
        } else {
            origin = NSPoint(x: area.maxX - size.width - 12, y: area.maxY - size.height - 6)
        }
        origin.x = min(max(origin.x, area.minX + 6), area.maxX - size.width - 6)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        removeOutsideClickMonitor()
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    func hide() {
        panel.orderOut(nil)
        removeOutsideClickMonitor()
    }

    /// Repeated opens (the tile, the URL, the menu bar icon) must not stack monitors.
    private func removeOutsideClickMonitor() {
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        outsideClick = nil
    }

    func windowDidResignKey(_ notification: Notification) { hide() }
}

// MARK: Model

/// Observable view of the default input device, kept live through CoreAudio property listeners.
@MainActor
final class InputModel: ObservableObject {
    @Published private(set) var devices: [InputDevice] = []
    @Published private(set) var currentID: AudioObjectID?
    @Published var volume: Double = 0
    @Published private(set) var hasVolume = false
    @Published private(set) var isMuted = false

    private var listenedDevice: AudioObjectID?
    private var listener: AudioObjectPropertyListenerBlock?
    private var isDragging = false
    private var tileState: String?

    init() {
        refresh()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
        listener = block
        let system = AudioObjectID(kAudioObjectSystemObject)
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] {
            var addr = AudioInput.address(selector)
            AudioObjectAddPropertyListenerBlock(system, &addr, DispatchQueue.main, block)
        }
    }

    func refresh() {
        devices = AudioInput.devices()
        currentID = AudioInput.defaultInputID()
        isMuted = AudioInput.isMuted() ?? false
        if let id = currentID, let v = AudioInput.volume(of: id) {
            hasVolume = true
            if !isDragging { volume = Double(v) }
        } else {
            hasVolume = false
            volume = 0
        }
        rebindVolumeListener()
        reloadTilesIfNeeded()
    }

    /// Control Center tiles show a snapshot, so they only update when asked. Ask when the default
    /// input or mute state changes, not on every volume tick.
    private func reloadTilesIfNeeded() {
        let state = "\(currentID ?? 0)-\(isMuted)"
        guard state != tileState else { return }
        tileState = state
        ControlCenter.shared.reloadAllControls()
    }

    func select(_ device: InputDevice) {
        AudioInput.setDefaultInput(device)
        refresh()
    }

    func setVolume(_ value: Double, dragging: Bool) {
        isDragging = dragging
        volume = value
        if let id = currentID { AudioInput.setVolume(Float32(value), on: id) }
        isMuted = value == 0
    }

    /// Re-attaches the volume listener to whichever device is the default input now.
    private func rebindVolumeListener() {
        guard let block = listener, listenedDevice != currentID else { return }
        if let old = listenedDevice {
            for el in [kAudioObjectPropertyElementMain, 1, 2] {
                var addr = AudioInput.address(kAudioDevicePropertyVolumeScalar,
                                              scope: kAudioDevicePropertyScopeInput, element: el)
                AudioObjectRemovePropertyListenerBlock(old, &addr, DispatchQueue.main, block)
            }
        }
        listenedDevice = currentID
        if let new = currentID {
            for el in [kAudioObjectPropertyElementMain, 1, 2] {
                var addr = AudioInput.address(kAudioDevicePropertyVolumeScalar,
                                              scope: kAudioDevicePropertyScopeInput, element: el)
                AudioObjectAddPropertyListenerBlock(new, &addr, DispatchQueue.main, block)
            }
        }
    }
}

// MARK: Panel

/// Same layout as the system Sound panel: title, volume slider, section header, device rows, settings link.
struct InputPanel: View {
    @ObservedObject var model: InputModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sound")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "mic")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                GlassSlider(
                    value: Binding(get: { model.volume }, set: { _ in }),
                    isEnabled: model.hasVolume
                ) { value, dragging in
                    model.setVolume(value, dragging: dragging)
                }
                Image(systemName: "mic.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)

            Divider().opacity(0.4)

            Text("Input")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                ForEach(model.devices) { device in
                    DeviceRow(device: device, isSelected: device.id == model.currentID) {
                        model.select(device)
                    }
                }
            }
            .padding(.horizontal, 8)

            Divider().opacity(0.4).padding(.top, 8)

            SettingsRow()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(width: 300)
    }
}

/// Hover flag as a plain ObservableObject. `@State` expands a SwiftUI macro whose plugin ships
/// only with Xcode.app, so it cannot compile with the command line tools alone.
final class HoverFlag: ObservableObject {
    @Published var isOn = false
}

struct DeviceRow: View {
    let device: InputDevice
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var hover = HoverFlag()
    private var hovering: Bool { hover.isOn }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(isSelected ? Color.white : Color.primary.opacity(0.16))
                    Image(systemName: device.symbolName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                }
                .frame(width: 24, height: 24)
                Text(device.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(hovering ? 0.12 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isOn = $0 }
    }
}

struct SettingsRow: View {
    @StateObject private var hover = HoverFlag()
    private var hovering: Bool { hover.isOn }

    var body: some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Text("Sound Settings…")
                .font(.system(size: 13))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(hovering ? 0.12 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isOn = $0 }
    }
}

/// Thin track, white fill, round white thumb: the Control Center slider look.
struct GlassSlider: View {
    @Binding var value: Double
    var isEnabled: Bool = true
    var onChange: (Double, Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            let thumb: CGFloat = 18
            let width = geo.size.width - thumb
            let x = CGFloat(value) * width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.22)).frame(height: 4)
                Capsule().fill(Color.white.opacity(0.95)).frame(width: x + thumb / 2, height: 4)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                    .offset(x: x)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let v = min(1, max(0, Double((drag.location.x - thumb / 2) / width)))
                        onChange(v, true)
                    }
                    .onEnded { _ in onChange(value, false) }
            )
        }
        .frame(height: 20)
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(isEnabled)
    }
}
