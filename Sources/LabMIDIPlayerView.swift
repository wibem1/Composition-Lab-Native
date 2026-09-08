import Cocoa

@MainActor
final class LabMIDIPlayerView: NSStackView {
    private let player = MIDIPlaybackController()
    private let progress = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    private let volume = NSSlider(value: 0.80, minValue: 0.10, maxValue: 1.0, target: nil, action: nil)
    private let tempoField = NSTextField(string: "120")
    private let tempoStepper = NSStepper()
    private let loopButton = NSButton(title: "↻ Loop", target: nil, action: nil)
    private var timer: Timer?
    private var score: Score?
    private var scoreFingerprint: Data?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .vertical
        alignment = .leading
        spacing = 5

        let transport = NSStackView()
        transport.orientation = .horizontal
        transport.spacing = 6
        transport.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(play)))
        transport.addArrangedSubview(NSButton(title: "Ⅱ", target: self, action: #selector(pause)))
        transport.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stop)))
        loopButton.setButtonType(.toggle)
        loopButton.bezelStyle = .rounded
        loopButton.target = self
        loopButton.action = #selector(loopChanged)
        transport.addArrangedSubview(loopButton)
        addArrangedSubview(transport)

        let progressRow = NSStackView()
        progressRow.orientation = .horizontal
        progressRow.spacing = 8
        progress.target = self
        progress.action = #selector(seek)
        progress.isContinuous = true
        progress.widthAnchor.constraint(equalToConstant: 250).isActive = true
        progressRow.addArrangedSubview(progress)
        progressRow.addArrangedSubview(timeLabel)
        addArrangedSubview(progressRow)

        let tempoRow = NSStackView()
        tempoRow.orientation = .horizontal
        tempoRow.spacing = 8
        tempoRow.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        tempoField.alignment = .right
        tempoField.target = self
        tempoField.action = #selector(tempoChanged)
        tempoField.widthAnchor.constraint(equalToConstant: 58).isActive = true
        tempoRow.addArrangedSubview(tempoField)
        tempoRow.addArrangedSubview(NSTextField(labelWithString: "BPM"))
        tempoStepper.minValue = 20
        tempoStepper.maxValue = 300
        tempoStepper.increment = 1
        tempoStepper.target = self
        tempoStepper.action = #selector(tempoStepperChanged)
        tempoRow.addArrangedSubview(tempoStepper)
        addArrangedSubview(tempoRow)

        let volumeRow = NSStackView()
        volumeRow.orientation = .horizontal
        volumeRow.spacing = 8
        volume.target = self
        volume.action = #selector(volumeChanged)
        volume.isContinuous = true
        volume.widthAnchor.constraint(equalToConstant: 180).isActive = true
        volumeRow.addArrangedSubview(NSTextField(labelWithString: "🔊 Lautstärke"))
        volumeRow.addArrangedSubview(volume)
        addArrangedSubview(volumeRow)

        NotificationCenter.default.addObserver(self, selector: #selector(outputModeChanged), name: MIDIOutputManager.changedNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setScore(_ score: Score?) {
        // Wichtig für die integrierten Arbeitsbereiche: Beim Seitenwechsel wird dieselbe
        // Partitur teilweise erneut an den Player übergeben. In diesem Fall darf ein vom
        // Nutzer gewähltes Wiedergabetempo nicht auf das Partiturtempo zurückspringen.
        let newFingerprint = score.flatMap { try? JSONEncoder().encode($0) }
        let sameScore = (newFingerprint != nil && newFingerprint == scoreFingerprint)
        let rememberedTempo = tempoField.integerValue

        self.score = score
        self.scoreFingerprint = newFingerprint

        guard let score else {
            player.stop()
            tempoField.stringValue = "—"
            tempoStepper.doubleValue = 120
            updateTime()
            return
        }

        let originalBPM = max(20, min(300, Int(score.bpm.rounded())))
        let bpm: Int
        if sameScore && rememberedTempo >= 20 && rememberedTempo <= 300 {
            bpm = rememberedTempo
        } else {
            bpm = originalBPM
        }
        tempoField.integerValue = bpm
        tempoStepper.integerValue = bpm
        load(score: score, keepFraction: 0, resume: false)
    }

    private func playbackScore(_ score: Score) -> Score {
        var sc = scaledScore(score, factor: volume.doubleValue)
        let requested = tempoField.integerValue
        sc.bpm = Double(max(20, min(300, requested > 0 ? requested : Int(score.bpm.rounded()))))
        return sc
    }

    private func scaledScore(_ score: Score, factor: Double) -> Score {
        var sc = score
        sc.tr = sc.tr.map { tr in
            var t = tr
            t.nt = tr.nt.map { n in
                var x = n
                if x.count > 3 { x[3] = max(1, min(127, x[3] * factor)) }
                return x
            }
            return t
        }
        return sc
    }

    private func load(score: Score, keepFraction: Double, resume: Bool) {
        let scaled = playbackScore(score)
        let data = MIDIBuilder.build(scaled)
        do {
            try player.load(score: scaled, data: data)
            player.seek(fraction: keepFraction)
            if resume { player.play(); startTimer() }
            updateTime()
        } catch {
            timeLabel.stringValue = "Playerfehler"
        }
    }

    @objc private func play() { player.play(); startTimer() }
    @objc private func loopChanged() {
        let active = (loopButton.state == .on)
        player.loopEnabled = active
        loopButton.title = active ? "↻ Loop AN" : "↻ Loop"
        loopButton.contentTintColor = active ? .systemGreen : nil
    }
    @objc private func pause() { player.pause(); updateTime() }
    @objc private func stop() { player.stop(); timer?.invalidate(); timer = nil; updateTime() }
    @objc private func seek() { player.seek(fraction: progress.doubleValue); updateTime() }
    @objc private func tempoStepperChanged() {
        tempoField.integerValue = tempoStepper.integerValue
        tempoChanged()
    }

    @objc private func tempoChanged() {
        guard let score else { return }
        var bpm = tempoField.integerValue
        if bpm <= 0 { bpm = Int(score.bpm.rounded()) }
        bpm = max(20, min(300, bpm))
        tempoField.integerValue = bpm
        tempoStepper.integerValue = bpm
        let wasPlaying = player.isPlaying
        let fraction = player.duration > 0 ? player.position / player.duration : 0
        load(score: score, keepFraction: fraction, resume: wasPlaying)
    }

    @objc private func volumeChanged() {
        guard let score else { return }
        let wasPlaying = player.isPlaying
        let fraction = player.duration > 0 ? player.position / player.duration : 0
        load(score: score, keepFraction: fraction, resume: wasPlaying)
    }

    @objc private func outputModeChanged() {
        player.outputModeChanged()
        updateTime()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(tick(_:)), userInfo: nil, repeats: true)
    }

    @objc private func tick(_ t: Timer) {
        updateTime()
        if !player.isPlaying { t.invalidate(); timer = nil }
    }

    private func updateTime() {
        func fmt(_ x: TimeInterval) -> String { let n=max(0,Int(x.rounded())); return String(format:"%d:%02d",n/60,n%60) }
        let dur = player.duration, pos = player.position
        timeLabel.stringValue = "\(fmt(pos)) / \(fmt(dur))"
        progress.doubleValue = dur > 0 ? max(0,min(1,pos/dur)) : 0
    }
}
