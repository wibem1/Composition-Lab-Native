import Foundation
import CoreMIDI
import AudioToolbox
import Darwin

@MainActor
final class MIDIOutputManager {
    static let shared = MIDIOutputManager()
    static let changedNotification = Notification.Name("CompositionLabMIDIOutputChanged")

    enum Mode: String { case internalSound, midiDestination }

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private let defaults = UserDefaults.standard

    private init() {
        MIDIClientCreate("Composition Lab MIDI Client" as CFString, nil, nil, &client)
        MIDIOutputPortCreate(client, "Composition Lab MIDI Out" as CFString, &outputPort)
    }

    deinit {
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    var mode: Mode {
        get { Mode(rawValue: defaults.string(forKey: "composition_lab_midi_output_mode") ?? "") ?? .internalSound }
        set { defaults.set(newValue.rawValue, forKey: "composition_lab_midi_output_mode"); NotificationCenter.default.post(name: Self.changedNotification, object: nil) }
    }

    var selectedUniqueID: MIDIUniqueID {
        get { MIDIUniqueID(defaults.integer(forKey: "composition_lab_midi_output_unique_id")) }
        set { defaults.set(Int(newValue), forKey: "composition_lab_midi_output_unique_id"); NotificationCenter.default.post(name: Self.changedNotification, object: nil) }
    }

    struct Destination { let endpoint: MIDIEndpointRef; let uniqueID: MIDIUniqueID; let name: String }

    func destinations() -> [Destination] {
        var result: [Destination] = []
        for i in 0..<MIDIGetNumberOfDestinations() {
            let ep = MIDIGetDestination(i)
            guard ep != 0 else { continue }
            var uid: Int32 = 0
            MIDIObjectGetIntegerProperty(ep, kMIDIPropertyUniqueID, &uid)
            var unmanaged: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(ep, kMIDIPropertyDisplayName, &unmanaged)
            let name = (unmanaged?.takeRetainedValue() as String?) ?? "MIDI-Ausgang \(i + 1)"
            result.append(Destination(endpoint: ep, uniqueID: MIDIUniqueID(uid), name: name))
        }
        return result
    }

    func selectedDestination() -> Destination? {
        let ds = destinations()
        if let d = ds.first(where: { $0.uniqueID == selectedUniqueID }) { return d }
        return ds.first
    }

    var selectedDestinationName: String? { selectedDestination()?.name }

    func send(_ bytes: [UInt8]) {
        send(bytes, atHostTime: 0)
    }

    /// Sendet ein MIDI-Ereignis mit optionalem CoreMIDI-Zeitstempel.
    /// Ein Zeitstempel > 0 wird vom IAC-Bus/Empfänger samplegenau geplant und
    /// ist damit wesentlich robuster als das unmittelbare Senden aus einem UI-Timer.
    func send(_ bytes: [UInt8], atHostTime hostTime: MIDITimeStamp) {
        guard mode == .midiDestination, let destination = selectedDestination(), !bytes.isEmpty else { return }
        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = MIDIPacketListAdd(&packetList,
                                  MemoryLayout<MIDIPacketList>.size,
                                  packet,
                                  hostTime,
                                  bytes.count,
                                  base)
        }
        MIDISend(outputPort, destination.endpoint, &packetList)
    }

    /// Reset the channel state before a fresh external MIDI playback.
    /// Deliberately avoids a GM SysEx reset so external instruments/DAWs keep their setup.
    func resetForPlayback() {
        guard mode == .midiDestination else { return }
        for ch in 0..<16 {
            let status = UInt8(0xB0 | ch)
            send([status, 64, 0])     // Sustain off
            send([status, 121, 0])    // Reset All Controllers
            send([status, 123, 0])    // All Notes Off
            send([UInt8(0xE0 | ch), 0, 64]) // Pitch Bend center (8192)
        }
    }

    /// Panic-style cleanup used when playback is paused, stopped, seeked or finishes.
    func allNotesOff() {
        guard mode == .midiDestination else { return }
        for ch in 0..<16 {
            let status = UInt8(0xB0 | ch)
            send([status, 64, 0])     // Sustain off
            send([status, 123, 0])    // All Notes Off
            send([status, 120, 0])    // All Sound Off as final safety net
        }
    }
}

@MainActor
final class ExternalMIDIPlayer {
    private var sequence: MusicSequence?
    private var player: MusicPlayer?
    private var monitorTimer: Timer?
    private var loadedScore: Score?
    private(set) var duration: TimeInterval = 0
    private let releaseTail: TimeInterval = 3.00
    private(set) var isPlaying = false
    private(set) var isPaused = false
    var onFinished: (() -> Void)?

    deinit {
        if let p = player {
            MusicPlayerStop(p)
            DisposeMusicPlayer(p)
        }
        if let s = sequence {
            DisposeMusicSequence(s)
        }
    }

    func load(score: Score) {
        stop()
        disposeEngine()
        loadedScore = score

        // Externe Wiedergabe wird als komplette Standard-MIDI-Datei an Apples
        // MusicSequence/MusicPlayer übergeben. Damit übernimmt Core Audio das
        // gesamte Timing; kein eigener Note-On/Off-Timer läuft mehr.
        let midiData = MIDIBuilder.build(score, endPaddingSeconds: releaseTail)

        var newSequence: MusicSequence?
        guard NewMusicSequence(&newSequence) == noErr, let seq = newSequence else {
            return
        }

        let loadStatus = midiData.withUnsafeBytes { rawBuffer -> OSStatus in
            let cfData = midiData as CFData
            return MusicSequenceFileLoadData(
                seq,
                cfData,
                .midiType,
                MusicSequenceLoadFlags()
            )
        }
        guard loadStatus == noErr else {
            DisposeMusicSequence(seq)
            return
        }

        var newPlayer: MusicPlayer?
        guard NewMusicPlayer(&newPlayer) == noErr, let mp = newPlayer else {
            DisposeMusicSequence(seq)
            return
        }

        guard MusicPlayerSetSequence(mp, seq) == noErr else {
            DisposeMusicPlayer(mp)
            DisposeMusicSequence(seq)
            return
        }

        sequence = seq
        player = mp

        let bpm = max(20.0, min(300.0, score.bpm))
        let maxBeat = score.tr
            .flatMap(\.nt)
            .filter { $0.count >= 2 }
            .map { max(0, $0[0]) + max(0.001, $0[1]) * ($0.count > 5 ? max(0.01, $0[5]) : 0.95) }
            .max() ?? 0
        duration = maxBeat > 0 ? (maxBeat * 60.0 / bpm) + releaseTail : 0

        MusicPlayerSetTime(mp, 0)
        MusicPlayerPreroll(mp)
        isPlaying = false
        isPaused = false
    }

    var position: TimeInterval {
        get {
            guard let mp = player, let score = loadedScore else { return 0 }
            var beat: MusicTimeStamp = 0
            guard MusicPlayerGetTime(mp, &beat) == noErr else { return 0 }
            let bpm = max(20.0, min(300.0, score.bpm))
            return max(0, min(duration, beat * 60.0 / bpm))
        }
        set {
            seek(to: newValue)
        }
    }

    func play() {
        guard let seq = sequence,
              let mp = player,
              let destination = MIDIOutputManager.shared.selectedDestination() else { return }

        MIDIOutputManager.shared.resetForPlayback()

        // Der IAC-Bus wird direkt als Ziel der kompletten MusicSequence gesetzt.
        // MusicPlayer/Core Audio planen die MIDI-Ereignisse selbst mit Echtzeit-Timing.
        guard MusicSequenceSetMIDIEndpoint(seq, destination.endpoint) == noErr else { return }

        MusicPlayerPreroll(mp)
        guard MusicPlayerStart(mp) == noErr else { return }

        isPlaying = true
        isPaused = false
        startMonitor()
    }

    func pause() {
        guard isPlaying, let mp = player else { return }
        MusicPlayerStop(mp)
        monitorTimer?.invalidate()
        monitorTimer = nil
        isPlaying = false
        isPaused = true
        MIDIOutputManager.shared.allNotesOff()
    }

    func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        if let mp = player {
            MusicPlayerStop(mp)
            MusicPlayerSetTime(mp, 0)
        }
        MIDIOutputManager.shared.allNotesOff()
        isPlaying = false
        isPaused = false
    }

    func seek(fraction: Double) {
        seek(to: max(0, min(1, fraction)) * duration)
    }

    private func seek(to value: TimeInterval) {
        guard let mp = player, let score = loadedScore else { return }
        let resume = isPlaying
        MusicPlayerStop(mp)
        MIDIOutputManager.shared.allNotesOff()

        let clamped = max(0, min(duration, value))
        let bpm = max(20.0, min(300.0, score.bpm))
        let beat = clamped * bpm / 60.0
        MusicPlayerSetTime(mp, beat)
        MusicPlayerPreroll(mp)

        isPlaying = false
        if resume { play() }
    }

    private func startMonitor() {
        monitorTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, target: self, selector: #selector(monitorTick(_:)), userInfo: nil, repeats: true)
        timer.tolerance = 0.01
        monitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func monitorTick(_ timer: Timer) {
        guard isPlaying else {
            timer.invalidate()
            return
        }

        if position >= duration - 0.01 {
            timer.invalidate()
            monitorTimer = nil
            if let mp = player { MusicPlayerStop(mp) }
            isPlaying = false
            isPaused = false
            MIDIOutputManager.shared.allNotesOff()
            onFinished?()
        }
    }

    private func disposeEngine() {
        monitorTimer?.invalidate()
        monitorTimer = nil

        if let mp = player {
            MusicPlayerStop(mp)
            DisposeMusicPlayer(mp)
            player = nil
        }
        if let seq = sequence {
            DisposeMusicSequence(seq)
            sequence = nil
        }
    }
}

