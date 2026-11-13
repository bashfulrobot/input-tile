import CoreAudio
import Foundation

/// One audio device that can capture sound.
struct InputDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let transport: UInt32

    /// SF Symbol matching how the system Sound panel icons each kind of device.
    var symbolName: String {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "display"
        case kAudioDeviceTransportTypeUSB: return "mic.fill"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        default: return "speaker.wave.2.fill"
        }
    }
}

/// CoreAudio helpers for listing input devices, switching the default input, and muting it.
enum AudioInput {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    // MARK: Devices

    /// Every device with at least one input channel, hidden devices excluded.
    static func devices() -> [InputDevice] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard inputChannelCount(id) > 0, !isHidden(id) else { return nil }
            guard let uid = stringProperty(id, kAudioDevicePropertyDeviceUID),
                  let name = stringProperty(id, kAudioObjectPropertyName) else { return nil }
            return InputDevice(id: id, uid: uid, name: name, transport: transportType(id))
        }
    }

    private static func transportType(_ id: AudioObjectID) -> UInt32 {
        var addr = address(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    static func defaultInputID() -> AudioObjectID? {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    static func defaultInput() -> InputDevice? {
        guard let id = defaultInputID() else { return nil }
        return devices().first { $0.id == id }
    }

    @discardableResult
    static func setDefaultInput(_ device: InputDevice) -> Bool {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = device.id
        let status = AudioObjectSetPropertyData(
            system, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id
        )
        return status == noErr
    }

    /// Switches to the next input device in the list, wrapping at the end.
    @discardableResult
    static func cycleDefaultInput() -> InputDevice? {
        let all = devices()
        guard !all.isEmpty else { return nil }
        let currentIndex = all.firstIndex { $0.id == defaultInputID() } ?? -1
        let next = all[(currentIndex + 1) % all.count]
        return setDefaultInput(next) ? next : nil
    }

    // MARK: Mute

    /// Mute state of the default input. Nil when the device exposes no mute or volume control.
    static func isMuted() -> Bool? {
        guard let id = defaultInputID() else { return nil }
        var addr = address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        guard AudioObjectHasProperty(id, &addr) else { return volumeIsZero(id) }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    @discardableResult
    static func setMuted(_ muted: Bool) -> Bool {
        guard let id = defaultInputID() else { return false }
        var addr = address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        if AudioObjectHasProperty(id, &addr) {
            var value: UInt32 = muted ? 1 : 0
            return AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
        }
        // No mute control: fall back to volume 0 and restore 1.0.
        return setVolume(muted ? 0 : 1, on: id)
    }

    // MARK: Private

    private static func volumeIsZero(_ id: AudioObjectID) -> Bool? {
        volume(of: id).map { $0 == 0 }
    }

    // MARK: Volume

    /// Elements that carry input volume: the main element when present, else channels 1 and 2.
    private static func volumeElements(_ id: AudioObjectID) -> [AudioObjectPropertyElement] {
        var main = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput)
        if AudioObjectHasProperty(id, &main) { return [kAudioObjectPropertyElementMain] }
        return [1, 2].filter { ch in
            var a = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput, element: ch)
            return AudioObjectHasProperty(id, &a)
        }
    }

    /// Input volume 0...1 of a device. Nil when the device has no volume control.
    static func volume(of id: AudioObjectID) -> Float32? {
        let values: [Float32] = volumeElements(id).compactMap { el in
            var a = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput, element: el)
            var v = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            return AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr ? v : nil
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float32(values.count)
    }

    @discardableResult
    static func setVolume(_ value: Float32, on id: AudioObjectID) -> Bool {
        let elements = volumeElements(id)
        guard !elements.isEmpty else { return false }
        var ok = true
        for el in elements {
            var a = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput, element: el)
            var v = max(0, min(1, value))
            ok = AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr && ok
        }
        return ok
    }

    private static func inputChannelCount(_ id: AudioObjectID) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func isHidden(_ id: AudioObjectID) -> Bool {
        var addr = address(kAudioDevicePropertyIsHidden)
        guard AudioObjectHasProperty(id, &addr) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    private static func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var ref: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &ref) == noErr,
              let ref else { return nil }
        return ref.takeRetainedValue() as String
    }
}
