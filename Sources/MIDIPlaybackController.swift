import Foundation
import AVFoundation

@MainActor
final class MIDIPlaybackController {
    private var internalPlayer: AVMIDIPlayer?
    private let externalPlayer = ExternalMIDIPlayer()
    private var tempURL: URL?
    private var loadedScore: Score?
    private(set) var isPaused = false
    var loopEnabled = false
    var onFinished: (() -> Void)?

    init() {
        externalPlayer.onFinished = { [weak self] in
            guard let self else { return }
            self.isPaused = false
            if self.loopEnabled {
                self.externalPlayer.seek(fraction: 0)
                self.externalPlayer.play()
            } else {
                self.onFinished?()
            }
        }
    }

    deinit {
        internalPlayer?.stop()
        Task { @MainActor [externalPlayer] in
            externalPlayer.stop()
        }
        if let u = tempURL { try? FileManager.default.removeItem(at: u) }
    }

    func load(score: Score, data: Data) throws {
        _ = data // Export-MIDI bleibt Referenz; der Player baut eine eigene gepufferte Kopie.
        stop()
        loadedScore = score
        externalPlayer.load(score: score)
        if let u = tempURL { try? FileManager.default.removeItem(at: u) }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("composition-lab-\(UUID().uuidString).mid")

        // Für die interne Wiedergabe wird eine Player-Kopie mit Nachklang erzeugt.
        // Exportierte MIDI-Dateien bleiben unverändert. Der zusätzliche Track-End-Abstand
        // verhindert, dass AVMIDIPlayer den Synthesizer direkt nach dem letzten Note-Off beendet.
        let playbackData = MIDIBuilder.build(score, endPaddingSeconds: 3.00)
        try playbackData.write(to: u)
        tempURL = u
        let bankPath = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
        let bank = FileManager.default.fileExists(atPath: bankPath) ? URL(fileURLWithPath: bankPath) : nil
        internalPlayer = try AVMIDIPlayer(contentsOf: u, soundBankURL: bank)
        internalPlayer?.prepareToPlay()
        isPaused = false
    }

    private var externalMode: Bool { MIDIOutputManager.shared.mode == .midiDestination }

    func play() {
        if externalMode {
            externalPlayer.play()
        } else {
            guard let p = internalPlayer else { return }
            p.play { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.isPaused = false
                    if self.loopEnabled {
                        p.currentPosition = 0
                        self.play()
                    } else {
                        self.onFinished?()
                    }
                }
            }
        }
        isPaused = false
    }

    func pause() {
        if externalMode {
            externalPlayer.pause(); isPaused = externalPlayer.isPaused
        } else {
            guard let p = internalPlayer, p.isPlaying else { return }
            let pos = p.currentPosition
            p.stop(); p.currentPosition = pos; isPaused = true
        }
    }

    func stop() {
        internalPlayer?.stop(); internalPlayer?.currentPosition = 0
        externalPlayer.stop(); isPaused = false
    }

    var duration: TimeInterval { externalMode ? externalPlayer.duration : (internalPlayer?.duration ?? 0) }
    var position: TimeInterval {
        get { externalMode ? externalPlayer.position : (internalPlayer?.currentPosition ?? 0) }
        set {
            if externalMode { externalPlayer.position = newValue }
            else { internalPlayer?.currentPosition = max(0, min(duration, newValue)) }
        }
    }
    var isPlaying: Bool { externalMode ? externalPlayer.isPlaying : (internalPlayer?.isPlaying ?? false) }

    func seek(fraction: Double) {
        guard duration > 0 else { return }
        if externalMode { externalPlayer.seek(fraction: fraction) }
        else { position = max(0, min(1, fraction)) * duration }
    }

    func outputModeChanged() {
        let f = duration > 0 ? position / duration : 0
        internalPlayer?.stop(); externalPlayer.stop(); isPaused = false
        if externalMode { externalPlayer.seek(fraction: f) }
        else { internalPlayer?.currentPosition = f * (internalPlayer?.duration ?? 0) }
    }
}
