import Foundation

/// Direkter MusicXML-Export aus der strukturierten Composition-Lab-Partitur.
/// Der MIDI-Weg bleibt vollständig unabhängig und unverändert.
struct MusicXMLDisplayOptions: Codable, Equatable {
    /// Raster in Viertelnoten-Beats. 0 = keine Einsatzquantisierung; 1/3 = Achteltriolen, 1/6 = Sechzehnteltriolen.
    var startGrid: Double = 0.25
    /// Lücken bis zu dieser Größe dürfen notatorisch durch Verlängern der vorigen Note geschlossen werden.
    var shortRestThreshold: Double = 0.25
    /// Mindestanteil, den eine klingende Note am Abstand bis zum nächsten Einsatz haben muss,
    /// damit die Notation bis zu diesem Einsatz verlängert werden darf.
    var occupancyThreshold: Double = 0.45
    /// Maximale Differenz für das Glätten einer Notendauer auf einen Standardwert.
    var durationTolerance: Double = 0.21
    /// Legacy-Feld aus V4.9.5. Bleibt für ältere gespeicherte Profile lesbar.
    var minimumNoteValue: Double? = nil
    /// Cubase-artiger Rhythmusmodus: "auto", "straight" oder "triplet".
    /// Optional, damit ältere gespeicherte Profile weiter dekodiert werden können.
    var rhythmMode: String? = "auto"
    /// Kleinster gerader Notenwert in Viertelnoten-Beats, z.B. 0.25 = 16tel.
    var minimumStraightNoteValue: Double? = 0.25
    /// Kleinster triolischer Notenwert in Viertelnoten-Beats,
    /// z.B. 1/6 = 16teltriole.
    var minimumTripletNoteValue: Double? = 1.0 / 6.0
    /// Mini-Pause direkt nach einer Taktgrenze bis zu diesem Wert entfernen. 0 = aus.
    var barStartSnapThreshold: Double = 0.25
    /// Zusammengesetzte Werte an Zählzeiten teilen und mit Haltebögen schreiben.
    var splitAtBeatBoundaries: Bool = true

    static let readablePiano = MusicXMLDisplayOptions()
    static let midiNear = MusicXMLDisplayOptions(
        startGrid: 0,
        shortRestThreshold: 0,
        occupancyThreshold: 1.0,
        durationTolerance: 0.02,
        minimumNoteValue: nil,
        rhythmMode: "auto",
        minimumStraightNoteValue: nil,
        minimumTripletNoteValue: nil,
        barStartSnapThreshold: 0,
        splitAtBeatBoundaries: false
    )
}

enum MusicXMLBuilder {
    static let divisions = 480

    static func build(_ score: Score, options: MusicXMLDisplayOptions = .readablePiano) -> Data? {
        let xml = makeXML(score, options: options)
        return xml.data(using: .utf8)
    }

    private struct XNote {
        /// Notatorisch quantisierte Position.
        let start: Double
        /// Ursprüngliche Position aus dem internen Score/MIDI.
        /// Sie darf durch Darstellungsquantisierung niemals verändert werden.
        let sourceStart: Double
        let duration: Double
        let pitch: Int
        let velocity: Int
        let staff: Int
        let gate: Double
    }

    private struct Fragment {
        /// Notatorische Position. Sie darf bei Vorschlagsnoten von der MIDI-Position abweichen.
        let start: Double
        /// Ursprüngliche MIDI-Position; wichtig für die Zuordnung der NotationEvents.
        let sourceStart: Double
        let duration: Double
        let pitch: Int
        let velocity: Int
        let staff: Int
        let gate: Double
        let tieStart: Bool
        let tieStop: Bool
    }

    /// Simultaneous notes with the same notated duration form a chord.
    /// Groups that overlap in time are distributed across independent MusicXML voices.
    private struct NoteGroup {
        let start: Double
        let duration: Double
        let notes: [Fragment]
        let isGrace: Bool
    }

    private static func makeXML(_ score: Score, options: MusicXMLDisplayOptions) -> String {
        let title = esc(score.ti)
        var out = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <work><work-title>\(title)</work-title></work>
          <identification>
            <encoding>
              <software>Composition Lab</software>
              <encoding-date>\(isoDate())</encoding-date>
            </encoding>
          </identification>
          <part-list>
        """

        for (i, track) in score.tr.enumerated() {
            let pid = "P\(i + 1)"
            out += """
              <score-part id="\(pid)">
                <part-name>\(esc(track.nm))</part-name>
                <midi-instrument id="\(pid)-I1">
                  <midi-channel>\(max(1, min(16, track.ch + 1)))</midi-channel>
                  <midi-program>\(max(1, min(128, track.pg + 1)))</midi-program>
                </midi-instrument>
              </score-part>
            """
        }
        out += "  </part-list>\n"

        for (i, track) in score.tr.enumerated() {
            out += makePart(track, index: i, score: score, options: options)
        }
        out += "</score-partwise>\n"
        return out
    }

    private static func makePart(_ track: Track, index: Int, score: Score, options: MusicXMLDisplayOptions) -> String {
        let pid = "P\(index + 1)"
        let measureLen = Double(score.ts.n) * 4.0 / Double(max(1, score.ts.d))
        // Der Score enthält Spielzeiten für MIDI. Für die Partitur werden daraus
        // separat saubere notatorische Dauern rekonstruiert. Dadurch bleiben z.B.
        // 3.8 Beats im MIDI unverändert, erscheinen im Notenbild aber als sinnvoller
        // 4-Beat-Wert statt als "fast ganze Note + winzige Restpause".
        struct RawNote {
            let start: Double
            let duration: Double
            let pitch: Int
            let velocity: Int
            let staff: Int
            let gate: Double
        }

        let rawNotes: [RawNote] = track.nt.compactMap { n in
            guard n.count >= 4 else { return nil }
            return RawNote(
                start: max(0, n[0]),
                duration: max(1.0 / Double(divisions), n[1]),
                pitch: max(0, min(127, Int(n[2].rounded()))),
                velocity: max(1, min(127, Int(n[3].rounded()))),
                staff: n.count > 4 ? max(1, Int(n[4].rounded())) : 1,
                gate: n.count > 5 ? n[5] : 0.95
            )
        }

        var notationStarts = rawNotes.map { quantizedNotationStart($0.start, options: options) }

        // Sehr kurze Auftakt-Pausen innerhalb eines normalen Taktes sind bei Klaviernotation
        // meist nur ein Überbleibsel der MIDI-Zeitlage. Wenn der erste Einsatz eines Systems
        // höchstens eine 16tel nach der Taktgrenze liegt, wird er für die Partitur auf die
        // Taktgrenze gezogen. MIDI und interner Score bleiben unverändert.
        for staff in Set(rawNotes.map(\.staff)) {
            let staffIndices = rawNotes.indices.filter { rawNotes[$0].staff == staff }
            let measures = Set(staffIndices.map { Int(floor(notationStarts[$0] / measureLen)) })

            for measureIndex in measures {
                let measureStart = Double(measureIndex) * measureLen
                let candidates = staffIndices.filter {
                    Int(floor(notationStarts[$0] / measureLen)) == measureIndex
                }
                guard let first = candidates.min(by: { notationStarts[$0] < notationStarts[$1] }) else { continue }
                let offset = notationStarts[first] - measureStart

                if options.barStartSnapThreshold > 0 && offset > 0.000_1 && offset <= options.barStartSnapThreshold + 0.000_1 {
                    notationStarts[first] = measureStart
                }
            }
        }

        let notes: [XNote] = rawNotes.enumerated().map { index, n in
            let notationStart = notationStarts[index]
            let laterStarts = rawNotes.indices
                .filter { rawNotes[$0].staff == n.staff &&
                          notationStarts[$0] > notationStart + 0.000_001 }
                .map { notationStarts[$0] }

            // Auch die nächste Taktgrenze ist ein natürlicher notatorischer Anker.
            // Damit wird z.B. eine bei 11.5 beginnende, ca. 0.35 Beat klingende Note
            // sauber als Achtelnote bis 12.0 notiert, statt 1/3 Beat + Mini-Pausen.
            let nextBarline = (floor(notationStart / measureLen) + 1.0) * measureLen
            let candidates = laterStarts + [nextBarline]
            let nextStart = candidates
                .filter { $0 > notationStart + 0.000_001 }
                .min()

            let notationDuration = quantizedNotationDuration(
                raw: n.duration,
                start: notationStart,
                nextStart: nextStart,
                options: options
            )

            let startTick = Int((notationStart * Double(divisions)).rounded())
            let endTick = max(startTick + 1,
                              Int(((notationStart + notationDuration) * Double(divisions)).rounded()))
            return XNote(
                start: Double(startTick) / Double(divisions),
                sourceStart: n.start,
                duration: Double(endTick - startTick) / Double(divisions),
                pitch: n.pitch,
                velocity: n.velocity,
                staff: n.staff,
                gate: n.gate
            )
        }
        let maxStaff = max(1, notes.map(\.staff).max() ?? 1)

        // Bei getrennten Klavierspuren wie „Piano – Rechte Hand“ / „Piano – Linke Hand“
        // muss die linke Hand auch dann im Bassschlüssel erscheinen, wenn sie als eigener
        // Track vorliegt. Zusätzlich hilft bei unbenannten Klavierspuren die mittlere Lage.
        let lowerTrackName = track.nm.lowercased()
        let explicitlyLeftHand =
            lowerTrackName.contains("linke hand") ||
            lowerTrackName.contains("left hand") ||
            lowerTrackName.contains("left-hand") ||
            lowerTrackName.contains(" lh")
        let pianoProgram = (0...7).contains(track.pg)
        let sortedPitches = notes.map(\.pitch).sorted()
        let medianPitch: Int? = sortedPitches.isEmpty ? nil : sortedPitches[sortedPitches.count / 2]
        let lowPianoTrack = pianoProgram && (medianPitch ?? 60) < 55
        let singleStaffUsesBassClef = maxStaff == 1 && (explicitlyLeftHand || lowPianoTrack)

        let maxEnd = notes.map { $0.start + $0.duration }.max() ?? measureLen
        let measureCount = max(1, Int(ceil(maxEnd / measureLen)))

        var fragmentsByMeasure = Array(repeating: [Fragment](), count: measureCount)
        for n in notes {
            var cursor = n.start
            var remaining = n.duration
            var firstOverall = true

            while remaining > 0.000_001 {
                let m = min(measureCount - 1, Int(floor(cursor / measureLen)))
                let boundary = Double(m + 1) * measureLen
                let barPiece = min(remaining, boundary - cursor)

                // Ein innerhalb des Taktes nicht direkt darstellbarer Wert (z.B. 2.5 oder
                // 3.5 Beats) wird in musikalisch normale, gebundene Werte zerlegt.
                // Dabei wird zuerst bis zur nächsten vollen Viertelgrenze geteilt.
                let subPieces = noteNotationPieces(duration: barPiece, start: cursor, options: options)
                var localCursor = cursor

                for (subIndex, subDuration) in subPieces.enumerated() {
                    let isLastSub = subIndex == subPieces.count - 1
                    let remainingAfterBarPiece = remaining - barPiece
                    let continues = !isLastSub || remainingAfterBarPiece > 0.000_001

                    fragmentsByMeasure[m].append(Fragment(
                        start: localCursor,
                        sourceStart: n.sourceStart,
                        duration: subDuration,
                        pitch: n.pitch,
                        velocity: n.velocity,
                        staff: min(maxStaff, max(1, n.staff)),
                        gate: n.gate,
                        tieStart: continues,
                        tieStop: !firstOverall
                    ))
                    firstOverall = false
                    localCursor += subDuration
                }

                cursor += barPiece
                remaining -= barPiece
            }
        }

        // Vorschlagsnoten, deren MIDI-Einsatz unmittelbar vor einer Taktgrenze liegt,
        // gehören notatorisch zur folgenden Hauptnote. Beispiel: 11.875 -> Hauptnote 12.0.
        // Der interne Score/MIDI-Zeitpunkt bleibt unverändert; nur die MusicXML-Position
        // wird an die folgende Hauptnote angeheftet.
        let graceWindow = 0.5
        if measureCount > 1 {
            for m in 0..<(measureCount - 1) {
                let boundary = Double(m + 1) * measureLen
                var keep: [Fragment] = []
                var move: [Fragment] = []

                for f in fragmentsByMeasure[m] {
                    let grace = graceKind(for: f, staff: f.staff, events: track.ev ?? [])
                    let endsAtBoundary = abs((f.sourceStart + f.duration) - boundary) < 0.000_1
                    let closeToBoundary = f.sourceStart < boundary &&
                                          boundary - f.sourceStart <= graceWindow + 0.000_1
                    let hasPrincipal = fragmentsByMeasure[m + 1].contains {
                        $0.staff == f.staff &&
                        abs($0.start - boundary) < 0.000_1 &&
                        graceKind(for: $0, staff: $0.staff, events: track.ev ?? []) == nil
                    }

                    if grace != nil && closeToBoundary && endsAtBoundary && hasPrincipal {
                        move.append(Fragment(
                            start: boundary,
                            sourceStart: f.sourceStart,
                            duration: f.duration,
                            pitch: f.pitch,
                            velocity: f.velocity,
                            staff: f.staff,
                            gate: f.gate,
                            tieStart: false,
                            tieStop: false
                        ))
                    } else {
                        keep.append(f)
                    }
                }

                fragmentsByMeasure[m] = keep
                if !move.isEmpty {
                    // Vor den Hauptnoten desselben Taktschlags einsortieren.
                    fragmentsByMeasure[m + 1].append(contentsOf: move)
                }
            }
        }

        var out = "  <part id=\"\(pid)\">\n"
        for m in 0..<measureCount {
            out += "    <measure number=\"\(m + 1)\">\n"
            if m == 0 {
                let fifths = keyFifths(score.k)
                out += """
                      <attributes>
                        <divisions>\(divisions)</divisions>
                        <key><fifths>\(fifths)</fifths></key>
                        <time><beats>\(score.ts.n)</beats><beat-type>\(score.ts.d)</beat-type></time>
                """
                if maxStaff > 1 {
                    out += "        <staves>\(maxStaff)</staves>\n"
                    out += "        <clef number=\"1\"><sign>G</sign><line>2</line></clef>\n"
                    out += "        <clef number=\"2\"><sign>F</sign><line>4</line></clef>\n"
                } else {
                    if singleStaffUsesBassClef {
                        out += "        <clef><sign>F</sign><line>4</line></clef>\n"
                    } else {
                        out += "        <clef><sign>\(defaultClefSign(track.pg))</sign><line>\(defaultClefLine(track.pg))</line></clef>\n"
                    }
                }
                out += "      </attributes>\n"
                if index == 0 {
                    out += tempoDirection(score.bpm)
                }
            }

            let semanticPedal = (track.ev ?? []).filter { $0.t.lowercased() == "pedal" }

            // Alte CC64-Partituren bleiben lesbar. Sobald semantisches Pedal vorhanden ist,
            // wird ausschließlich dieses für das Notenbild verwendet.
            if semanticPedal.isEmpty, let controls = track.ct {
                let measureStart = Double(m) * measureLen
                let measureEnd = measureStart + measureLen
                for c in controls where c.count >= 3 && c[0] >= measureStart && c[0] < measureEnd && Int(c[1].rounded()) == 64 {
                    let offset = Int(((c[0] - measureStart) * Double(divisions)).rounded())
                    let down = c[2] >= 64
                    out += """
                          <direction placement="below">
                            <offset>\(offset)</offset>
                            <direction-type><pedal type="\(down ? "start" : "stop")" line="yes"/></direction-type>
                          </direction>
                    """
                }
            }


            // Explizite Notations-/Ausdrucksereignisse aus der JSON-Partitur.
            if let events = track.ev {
                let measureStart = Double(m) * measureLen
                let measureEnd = measureStart + measureLen

                for ev in events where ev.b >= measureStart && ev.b < measureEnd {
                    switch ev.t.lowercased() {
                    case "dyn":
                        if let value = ev.v, !value.isEmpty {
                            out += dynamicDirection(value, beat: ev.b, measureStart: measureStart, staff: ev.st)
                        }
                    case "tempo":
                        out += expressiveTempoDirection(ev, measureStart: measureStart)
                    case "words":
                        if let value = ev.v, !value.isEmpty {
                            out += wordsDirection(value, beat: ev.b, measureStart: measureStart, staff: ev.st)
                        }
                    case "pedal":
                        if let value = ev.v {
                            out += pedalDirection(type: value, beat: ev.b, measureStart: measureStart, staff: ev.st)
                        }
                    case "wedge":
                        if let value = ev.v, let end = ev.e, end > ev.b {
                            out += wedgeDirection(type: value, beat: ev.b, measureStart: measureStart, staff: ev.st, start: true)
                        }
                    default:
                        break
                    }
                }

                // Endpunkte von Crescendo-/Diminuendo-Gabeln können in einem späteren Takt liegen.
                for ev in events where ev.t.lowercased() == "wedge" {
                    if let end = ev.e, end >= measureStart && end < measureEnd {
                        out += wedgeDirection(type: ev.v ?? "crescendo", beat: end, measureStart: measureStart, staff: ev.st, start: false)
                    }
                }
            }

            for staff in 1...maxStaff {
                if staff > 1 {
                    out += "      <backup><duration>\(measureTicks(score))</duration></backup>\n"
                }
                let measureStart = Double(m) * measureLen
                let measureEnd = measureStart + measureLen
                let frags = fragmentsByMeasure[m]
                    .filter { $0.staff == staff }
                    .sorted {
                        if abs($0.start - $1.start) > 0.000_001 { return $0.start < $1.start }
                        let g0 = graceKind(for: $0, staff: staff, events: track.ev ?? []) != nil
                        let g1 = graceKind(for: $1, staff: staff, events: track.ev ?? []) != nil
                        if g0 != g1 { return g0 && !g1 }
                        if abs($0.duration - $1.duration) > 0.000_001 { return $0.duration > $1.duration }
                        return $0.pitch < $1.pitch
                    }

                let voices = makeVoices(frags, staff: staff, events: track.ev ?? [])
                let actualVoices = voices.isEmpty ? [[]] : voices

                for (voiceIndex, groups) in actualVoices.enumerated() {
                    if voiceIndex > 0 {
                        out += "      <backup><duration>\(measureTicks(score))</duration></backup>\n"
                    }
                    let voice = voiceIndex + 1
                    var cursor = measureStart
                    var graceCoveredUntil = measureStart

                    for (groupIndex, group) in groups.enumerated() {
                        if group.start > cursor + 0.000_001 {
                            if graceCoveredUntil >= group.start - 0.000_001 {
                                cursor = group.start
                            } else {
                                out += restXML(duration: group.start - cursor,
                                               staff: staff,
                                               maxStaff: maxStaff,
                                               voice: voice,
                                               options: options,
                                               visible: voice == 1)
                                cursor = group.start
                            }
                        }

                        let beam = beamInfo(for: groups, index: groupIndex)
                        for (gIndex, f) in group.notes.enumerated() {
                            out += noteXML(f,
                                           chord: gIndex > 0,
                                           staff: staff,
                                           maxStaff: maxStaff,
                                           events: track.ev ?? [],
                                           voice: voice,
                                           options: options,
                                           beam: beam)
                        }

                        if group.isGrace {
                            // Eine Vorschlagnote erhält in MusicXML keine rhythmische Dauer.
                            // Ihre reale MIDI-Dauer darf daher weder den Takt überfüllen noch
                            // eine künstliche Pause vor der Hauptnote erzeugen.
                            graceCoveredUntil = max(graceCoveredUntil, group.start + group.duration)
                        } else {
                            cursor = max(cursor, group.start + group.duration)
                        }
                    }

                    if cursor < measureEnd - 0.000_001 {
                        out += restXML(duration: measureEnd - cursor,
                                       staff: staff,
                                       maxStaff: maxStaff,
                                       voice: voice,
                                       options: options,
                                       visible: voice == 1)
                    }
                }
            }

            out += "    </measure>\n"
        }
        out += "  </part>\n"
        return out
    }

    /// Bildet echte MusicXML-Stimmen innerhalb eines Systems. Ein einzelner MIDI-/Score-Staff
    /// kann gleichzeitig gehaltene und neu einsetzende Noten enthalten. Diese dürfen in MusicXML
    /// nicht einfach hintereinander geschrieben werden, weil sonst der Takt rechnerisch zu lang wird.
    private static func makeVoices(_ fragments: [Fragment], staff: Int, events: [NotationEvent]) -> [[NoteGroup]] {
        guard !fragments.isEmpty else { return [] }

        // Zuerst echte Akkorde bilden: gleicher Einsatz und gleiche Dauer. Unterschiedliche
        // Dauern am selben Einsatz bleiben getrennte Gruppen und können dadurch eigene Stimmen bilden.
        var groups: [NoteGroup] = []
        var i = 0
        while i < fragments.count {
            let first = fragments[i]
            var chord = [first]
            var j = i + 1
            while j < fragments.count,
                  abs(fragments[j].start - first.start) < 0.000_001,
                  abs(fragments[j].duration - first.duration) < 0.000_001 {
                chord.append(fragments[j])
                j += 1
            }
            let grace = chord.allSatisfy { graceKind(for: $0, staff: staff, events: events) != nil }
            groups.append(NoteGroup(start: first.start,
                                    duration: first.duration,
                                    notes: chord,
                                    isGrace: grace))
            i = j
        }

        // Greedy interval partitioning: jede überlappende Gruppe erhält eine weitere Stimme.
        // Vorschlagnote zählt rhythmisch als Dauer 0 und blockiert daher keine zusätzliche Stimme.
        var voices: [[NoteGroup]] = []
        var ends: [Double] = []
        for group in groups {
            var chosen: Int? = nil
            for v in 0..<voices.count where ends[v] <= group.start + 0.000_001 {
                chosen = v
                break
            }
            if let v = chosen {
                voices[v].append(group)
                if !group.isGrace { ends[v] = group.start + group.duration }
            } else {
                voices.append([group])
                ends.append(group.isGrace ? group.start : group.start + group.duration)
            }
        }
        return voices
    }

    private static func measureTicks(_ score: Score) -> Int {
        let beats = Double(score.ts.n) * 4.0 / Double(max(1, score.ts.d))
        return max(1, Int((beats * Double(divisions)).rounded()))
    }

    private struct BeamInfo {
        let primary: String?
        let secondary: String?
    }

    /// Konservative Balkengruppierung innerhalb einer Viertelzählzeit.
    /// Pausen, Unterbrechungen und Zählzeitgrenzen trennen Balkengruppen.
    private static func beamInfo(for groups: [NoteGroup], index: Int) -> BeamInfo {
        guard index >= 0 && index < groups.count else { return BeamInfo(primary: nil, secondary: nil) }
        let g = groups[index]
        guard !g.isGrace, g.duration <= 0.5 + 0.0001 else {
            return BeamInfo(primary: nil, secondary: nil)
        }

        func beamable(_ x: NoteGroup) -> Bool {
            !x.isGrace && x.duration <= 0.5 + 0.0001
        }
        func sameBeat(_ a: NoteGroup, _ b: NoteGroup) -> Bool {
            Int(floor(a.start + 0.0001)) == Int(floor(b.start + 0.0001))
        }
        func contiguous(_ a: NoteGroup, _ b: NoteGroup) -> Bool {
            abs((a.start + a.duration) - b.start) < 0.02
        }

        let prevOK: Bool = {
            guard index > 0 else { return false }
            let p = groups[index - 1]
            return beamable(p) && sameBeat(p, g) && contiguous(p, g)
        }()
        let nextOK: Bool = {
            guard index + 1 < groups.count else { return false }
            let n = groups[index + 1]
            return beamable(n) && sameBeat(g, n) && contiguous(g, n)
        }()

        let primary: String?
        if !prevOK && nextOK { primary = "begin" }
        else if prevOK && nextOK { primary = "continue" }
        else if prevOK && !nextOK { primary = "end" }
        else { primary = nil }

        let secondary = g.duration <= 0.25 + 0.0001 ? primary : nil
        return BeamInfo(primary: primary, secondary: secondary)
    }

    private static func noteXML(_ f: Fragment, chord: Bool, staff: Int, maxStaff: Int, events: [NotationEvent], voice: Int = 1, options: MusicXMLDisplayOptions, beam: BeamInfo? = nil) -> String {
        let p = pitchXML(f.pitch)
        let ticks = max(1, Int((f.duration * Double(divisions)).rounded()))
        let notation = durationNotation(f.duration, options: options)

        let grace = graceKind(for: f, staff: staff, events: events)

        var out = "      <note>\n"
        if chord { out += "        <chord/>\n" }
        if let grace {
            let slash = grace == "acciaccatura" ? "yes" : "no"
            out += "        <grace slash=\"\(slash)\" steal-time-following=\"20\"/>\n"
        }
        out += "        <pitch><step>\(p.step)</step>\(p.alter.map { "<alter>\($0)</alter>" } ?? "")<octave>\(p.octave)</octave></pitch>\n"
        if grace == nil {
            out += "        <duration>\(ticks)</duration>\n"
        }
        out += "        <voice>\(voice)</voice>\n"
        // Grace Notes haben keine metrische Dauer, brauchen aber einen grafischen
        // Notenwert. Wir notieren sie bewusst als kleine Achtel-Vorschlagsnote.
        if grace != nil {
            out += "        <type>eighth</type>\n"
        } else if let type = notation.type {
            out += "        <type>\(type)</type>\n"
            for _ in 0..<notation.dots { out += "        <dot/>\n" }
        }
        if !chord, grace == nil, let beam {
            if let primary = beam.primary {
                out += "        <beam number=\"1\">\(primary)</beam>\n"
            }
            if let secondary = beam.secondary {
                out += "        <beam number=\"2\">\(secondary)</beam>\n"
            }
        }
        if let tm = notation.timeModification, grace == nil {
            out += "        <time-modification><actual-notes>\(tm.actual)</actual-notes><normal-notes>\(tm.normal)</normal-notes></time-modification>\n"
        }
        if maxStaff > 1 { out += "        <staff>\(staff)</staff>\n" }
        out += "        <velocity>\(f.velocity)</velocity>\n"

        // Neben den automatisch erzeugten Bindungen für in Teilnoten zerlegte lange
        // Noten werden auch explizite, aus MusicXML importierte tie-Ereignisse
        // berücksichtigt. Ein tie-Event beschreibt den Startbeat b und den Beat e
        // der gebundenen Folgenoten; Pitch/Staff begrenzen die Zuordnung.
        let explicitTieStart = events.contains { ev in
            guard ev.t.lowercased() == "tie", abs(ev.b - f.sourceStart) < 0.000_1 else { return false }
            if let st = ev.st, st != staff { return false }
            if let pitch = ev.p, pitch != f.pitch { return false }
            return ev.e != nil
        }
        let explicitTieStop = events.contains { ev in
            guard ev.t.lowercased() == "tie", let end = ev.e, abs(end - f.sourceStart) < 0.000_1 else { return false }
            if let st = ev.st, st != staff { return false }
            if let pitch = ev.p, pitch != f.pitch { return false }
            return true
        }
        let tieStop = f.tieStop || explicitTieStop
        let tieStart = f.tieStart || explicitTieStart

        if grace == nil {
            if tieStop { out += "        <tie type=\"stop\"/>\n" }
            if tieStart { out += "        <tie type=\"start\"/>\n" }
        }

        var notations = ""
        if grace == nil {
            if tieStop { notations += "<tied type=\"stop\"/>" }
            if tieStart { notations += "<tied type=\"start\"/>" }
        }

        let matching = events.filter { eventMatchesNote($0, fragment: f, staff: staff) }
        let arts = matching.filter { $0.t.lowercased() == "art" }.compactMap { $0.v?.lowercased() }
        if !arts.isEmpty {
            var articulations = ""
            var other = ""
            for a in arts {
                switch a {
                case "staccato": articulations += "<staccato/>"
                case "tenuto": articulations += "<tenuto/>"
                case "accent": articulations += "<accent/>"
                case "marcato": articulations += "<strong-accent type=\"up\"/>"
                case "fermata": other += "<fermata type=\"upright\"/>"
                default: break
                }
            }
            if !articulations.isEmpty { notations += "<articulations>\(articulations)</articulations>" }
            notations += other
        }

        // Explizite Ornamente: Triller werden als "tr" und – bei Bereich – mit Trillerlinie notiert.
        let ornaments = matching.filter { $0.t.lowercased() == "orn" && $0.v?.lowercased() == "trill" }
        if !ornaments.isEmpty {
            var ornamentXML = "<trill-mark/>"
            if ornaments.contains(where: { $0.e != nil }) {
                ornamentXML += "<wavy-line type=\"start\" number=\"1\"/>"
            }
            notations += "<ornaments>\(ornamentXML)</ornaments>"
        }

        // Ende einer Trillerlinie an der Note am Endbeat.
        for ev in events where ev.t.lowercased() == "orn" && ev.v?.lowercased() == "trill" {
            let staffOK = ev.st == nil || ev.st == staff
            if staffOK, let end = ev.e, abs(end - f.start) < 0.000_1 {
                notations += "<ornaments><wavy-line type=\"stop\" number=\"1\"/></ornaments>"
            }
        }

        // Phrasierungsbögen werden an die Noten am Start-/Endbeat gehängt.
        for ev in events where ev.t.lowercased() == "slur" {
            let staffOK = ev.st == nil || ev.st == staff
            if staffOK && abs(ev.b - f.start) < 0.000_1 {
                notations += "<slur type=\"start\" number=\"1\"/>"
            }
            if staffOK, let end = ev.e, abs(end - f.start) < 0.000_1 {
                notations += "<slur type=\"stop\" number=\"1\"/>"
            }
        }

        if !notations.isEmpty { out += "        <notations>\(notations)</notations>\n" }
        out += "      </note>\n"
        return out
    }

    private static func restXML(duration: Double, staff: Int, maxStaff: Int, voice: Int = 1, options: MusicXMLDisplayOptions, visible: Bool = true) -> String {
        // Eine längere oder zusammengesetzte Lücke wird in reguläre Pausenwerte zerlegt,
        // statt einen MusicXML-Dauerwert ohne passenden grafischen <type> zu erzeugen.
        let pieces = notationPieces(duration, options: options)
        var out = ""
        for piece in pieces {
            let ticks = max(1, Int((piece * Double(divisions)).rounded()))
            let notation = durationNotation(piece, options: options)
            out += """
                  <note\(visible ? "" : " print-object=\"no\"")>
                    <rest/>
                    <duration>\(ticks)</duration>
                    <voice>\(voice)</voice>
            """
            if let type = notation.type {
                out += "        <type>\(type)</type>\n"
                for _ in 0..<notation.dots { out += "        <dot/>\n" }
            }
            if let tm = notation.timeModification {
                out += "        <time-modification><actual-notes>\(tm.actual)</actual-notes><normal-notes>\(tm.normal)</normal-notes></time-modification>\n"
            }
            if maxStaff > 1 { out += "        <staff>\(staff)</staff>\n" }
            out += "      </note>\n"
        }
        return out
    }

    private static func tempoDirection(_ bpm: Double) -> String {
        let shown = String(format: "%.0f", bpm)
        return """
              <direction placement="above">
                <direction-type>
                  <metronome><beat-unit>quarter</beat-unit><per-minute>\(shown)</per-minute></metronome>
                </direction-type>
                <sound tempo="\(bpm)"/>
              </direction>
        """
    }

    private static func graceKind(for fragment: Fragment, staff: Int, events: [NotationEvent]) -> String? {
        for ev in events {
            guard ev.t.lowercased() == "orn",
                  let value = ev.v?.lowercased(),
                  value == "acciaccatura" || value == "appoggiatura",
                  eventMatchesNote(ev, fragment: fragment, staff: staff)
            else { continue }
            return value
        }
        return nil
    }

    private static func eventMatchesNote(_ ev: NotationEvent, fragment: Fragment, staff: Int) -> Bool {
        guard abs(ev.b - fragment.sourceStart) < 0.000_1 else { return false }
        if let st = ev.st, st != staff { return false }
        if let pitch = ev.p, pitch != fragment.pitch { return false }
        return true
    }

    private static func offsetTicks(_ beat: Double, _ measureStart: Double) -> Int {
        Int(((beat - measureStart) * Double(divisions)).rounded())
    }

    private static func staffXML(_ staff: Int?) -> String {
        guard let staff, staff > 0 else { return "" }
        return "        <staff>\(staff)</staff>\n"
    }

    private static func dynamicDirection(_ value: String, beat: Double, measureStart: Double, staff: Int?) -> String {
        let allowed = ["pp","p","mp","mf","f","ff","sf","sfz","fp"]
        let mark = allowed.contains(value.lowercased()) ? value.lowercased() : "mf"
        return """
              <direction placement="below">
                <offset>\(offsetTicks(beat, measureStart))</offset>
                <direction-type><dynamics><\(mark)/></dynamics></direction-type>
        \(staffXML(staff))      </direction>
        """
    }

    private static func wordsDirection(_ value: String, beat: Double, measureStart: Double, staff: Int?) -> String {
        return """
              <direction placement="above">
                <offset>\(offsetTicks(beat, measureStart))</offset>
                <direction-type><words>\(esc(value))</words></direction-type>
        \(staffXML(staff))      </direction>
        """
    }

    private static func expressiveTempoDirection(_ ev: NotationEvent, measureStart: Double) -> String {
        let rawText = (ev.v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = rawText.lowercased()

        // In gedruckten Partituren stehen rit./accel./a tempo normalerweise als
        // Ausdruckstext. Eine zusätzliche Metronomzahl an jeder solchen Stelle
        // überlädt das Notenbild unnötig. Der numerische Zielwert bleibt als
        // unsichtbare <sound tempo="...">-Information erhalten.
        let isReturn =
            lower.contains("a tempo") ||
            lower.contains("tempo primo") ||
            lower.contains("tempo i")
        let isGradual =
            lower.contains("rit") ||
            lower.contains("rall") ||
            lower.contains("accel") ||
            lower.contains("stringendo")

        let words = rawText.isEmpty ? "" : "<words>\(esc(rawText))</words>"
        let sound = ev.n.map { "<sound tempo=\"\($0)\"/>" } ?? ""

        // Eine sichtbare Metronomzahl gibt es nur bei einer echten neuen
        // Tempo-Festlegung, nicht bei ritardando/accelerando/a tempo.
        let metro: String
        if !isReturn && !isGradual, let bpm = ev.n {
            metro = "<metronome><beat-unit>quarter</beat-unit><per-minute>\(String(format: "%.0f", bpm))</per-minute></metronome>"
        } else {
            metro = ""
        }

        // Ein völlig leeres Event ohne Text und ohne BPM hat nichts zu zeigen.
        if words.isEmpty && metro.isEmpty && sound.isEmpty { return "" }

        return """
              <direction placement="above">
                <offset>\(offsetTicks(ev.b, measureStart))</offset>
                <direction-type>\(words)\(metro)</direction-type>
        \(staffXML(ev.st))        \(sound)
              </direction>
        """
    }

    private static func pedalDirection(type: String, beat: Double, measureStart: Double, staff: Int?) -> String {
        let kind: String
        switch type.lowercased() {
        case "start": kind = "start"
        case "change": kind = "change"
        case "stop": kind = "stop"
        default: return ""
        }
        return """
              <direction placement="below">
                <offset>\(offsetTicks(beat, measureStart))</offset>
                <direction-type><pedal type="\(kind)" line="yes"/></direction-type>
        \(staffXML(staff))      </direction>
        """
    }

    private static func wedgeDirection(type: String, beat: Double, measureStart: Double, staff: Int?, start: Bool) -> String {
        let kind: String
        if start {
            kind = type.lowercased().contains("dim") ? "diminuendo" : "crescendo"
        } else {
            kind = "stop"
        }
        return """
              <direction placement="below">
                <offset>\(offsetTicks(beat, measureStart))</offset>
                <direction-type><wedge type="\(kind)" number="1"/></direction-type>
        \(staffXML(staff))      </direction>
        """
    }

    private static func pitchXML(_ midi: Int) -> (step: String, alter: Int?, octave: Int) {
        let names: [(String, Int?)] = [
            ("C",nil),("C",1),("D",nil),("E",-1),("E",nil),("F",nil),
            ("F",1),("G",nil),("A",-1),("A",nil),("B",-1),("B",nil)
        ]
        let pc = ((midi % 12) + 12) % 12
        let o = midi / 12 - 1
        return (names[pc].0, names[pc].1, o)
    }

    private static let notationDurations: [(Double,String,Int)] = [
        (8,"breve",0),
        (6,"whole",1),
        (4,"whole",0),
        (3,"half",1),
        (2,"half",0),
        (1.5,"quarter",1),
        (1,"quarter",0),
        (0.75,"eighth",1),
        (0.5,"eighth",0),
        (0.375,"16th",1),
        (0.25,"16th",0),
        (0.1875,"32nd",1),
        (0.125,"32nd",0),
        (0.0625,"64th",0)
    ]

    /// Notatorische Einsatzquantisierung auf ein lesbares 16tel-Raster.
    /// Beispiel: 9.375 -> 9.5. Exakte Viertel-/Achtel-/16tel-Positionen bleiben erhalten.
    /// Diese Änderung betrifft ausschließlich MusicXML, niemals MIDI oder internen Score.
    private static func effectiveRhythmMode(_ options: MusicXMLDisplayOptions) -> String {
        let m = options.rhythmMode ?? "auto"
        return ["auto", "straight", "triplet"].contains(m) ? m : "auto"
    }

    /// True nur dann, wenn die Darstellung ausdrücklich rein triolisch arbeitet.
    /// Im Auto-Modus dürfen gerade und triolische Werte nebeneinander vorkommen.
    private static func isTripletGrid(_ options: MusicXMLDisplayOptions) -> Bool {
        effectiveRhythmMode(options) == "triplet"
    }

    private static func effectiveStraightMinimum(_ options: MusicXMLDisplayOptions) -> Double? {
        if let v = options.minimumStraightNoteValue { return v }
        if let legacy = options.minimumNoteValue { return legacy }
        // Migration älterer Profile: binäres Einsatzraster als sinnvoller Ausgangswert übernehmen.
        if options.startGrid > 0 &&
           abs(options.startGrid - 1.0/3.0) > 0.01 &&
           abs(options.startGrid - 1.0/6.0) > 0.01 {
            return options.startGrid
        }
        return nil
    }

    private static func effectiveTripletMinimum(_ options: MusicXMLDisplayOptions) -> Double? {
        if let v = options.minimumTripletNoteValue { return v }
        // Migration älterer triolischer Profile.
        if abs(options.startGrid - 1.0/3.0) < 0.01 { return 1.0/3.0 }
        if abs(options.startGrid - 1.0/6.0) < 0.01 { return 1.0/6.0 }
        return nil
    }

    /// Darstellungsquantisierung der Einsatzpositionen.
    /// "Auto" prüft gerades und triolisches Raster und nimmt den näheren Rasterpunkt.
    /// MIDI und interner Score bleiben unverändert.
    private static func quantizedNotationStart(_ raw: Double, options: MusicXMLDisplayOptions) -> Double {
        let mode = effectiveRhythmMode(options)
        var candidates: [Double] = []

        if mode != "triplet", let grid = effectiveStraightMinimum(options), grid > 0 {
            candidates.append((raw / grid).rounded() * grid)
        }
        if mode != "straight", let grid = effectiveTripletMinimum(options), grid > 0 {
            candidates.append((raw / grid).rounded() * grid)
        }

        guard !candidates.isEmpty else { return raw }
        return candidates.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? raw
    }

    /// Rein notatorische Quantisierung. MIDI und interner Score bleiben unverändert.
    /// 1) Kleine Lücken bis zum nächsten Einsatz werden als Artikulations-/Gate-Effekt
    ///    behandelt und im Notenbild geschlossen.
    /// 2) Sonst wird auf den nächstliegenden gebräuchlichen Notenwert gerundet.
    private static func quantizedNotationDuration(raw: Double, start: Double, nextStart: Double?, options: MusicXMLDisplayOptions) -> Double {
        let candidates = notationDurations(for: options).map(\.0)
        let minimum = candidates.min() ?? 0.0625
        let base = max(0.0625, raw)
        // Reine Darstellungsquantisierung: die Dauer wird nie unter den kleinsten
        // im aktuellen Rhythmusmodus zugelassenen Wert gedrückt.
        let r = max(minimum, base)

        if let nextStart, nextStart > start {
            let interval = nextStart - start
            let tail = interval - r
            let intervalIsClean = notationDurations(for: options).contains { abs($0.0 - interval) < 0.02 }

            // Partiturinterpretation statt MIDI-Abschrift:
            // Wenn der nächste Einsatz auf einem klaren rhythmischen Rasterpunkt liegt
            // und die klingende Note wenigstens ungefähr die Hälfte dieses Zeitraums
            // ausfüllt, wird sie notatorisch bis zum nächsten Einsatz geführt.
            //
            // Beispiel: Start 0.5, MIDI-Dauer 0.5, nächster Einsatz 1.5:
            // Wiedergabe bleibt eine kurze Note; die Partitur zeigt eine Viertelnote
            // statt Achtelnote + Achtelpause.
            //
            // Größere echte Zwischenräume bleiben dagegen als Pausen sichtbar.
            let occupancy = r / interval
            if intervalIsClean &&
               tail >= -0.02 &&
               occupancy >= options.occupancyThreshold &&
               tail <= max(options.shortRestThreshold, 0.000_1) {
                return interval
            }

            // Kleine Gate-/Artikulationslücken weiterhin schließen.
            if options.shortRestThreshold > 0 && intervalIsClean && abs(tail) <= options.shortRestThreshold {
                return interval
            }
        }

        if let nearest = notationDurations(for: options).min(by: { abs($0.0-r) < abs($1.0-r) }) {
            let delta = abs(nearest.0 - r)
            // Moderate expressive Abweichungen (z.B. 1.2, 1.65, 3.8) werden
            // für die Partitur bereinigt; extreme Unterschiede bleiben unangetastet.
            if options.durationTolerance > 0 && delta <= max(options.durationTolerance, r * 0.15) {
                return nearest.0
            }
        }
        return r
    }

    /// Zerlegt Notendauern in für Pianisten lesbare Standardwerte.
    /// Beispiel:
    /// - Start 1.5, Dauer 2.5 -> 0.5 + 2.0 (Achtel gebunden an Halbe)
    /// - Start 0.5, Dauer 3.5 -> 0.5 + 3.0 (Achtel gebunden an punktierte Halbe)
    ///
    /// Dadurch entstehen keine typ-losen 2.5-/3.5-Beat-Noten mehr.
    private static func noteNotationPieces(duration: Double, start: Double, options: MusicXMLDisplayOptions) -> [Double] {
        var remaining = max(0, duration)
        if remaining < 0.000_001 { return [] }

        var result: [Double] = []
        var cursor = start
        let triplet = isTripletGrid(options)

        // Binäre Darstellung darf an Viertelgrenzen geteilt werden.
        // Bei triolischem Raster bleiben die 3er-Gruppen als Einheit erhalten.
        let frac = cursor - floor(cursor)
        if options.splitAtBeatBoundaries && !triplet && frac > 0.000_1 {
            let toBeat = 1.0 - frac
            let minimum = notationDurations(for: options).map(\.0).min() ?? 0.0
            if toBeat <= remaining + 0.000_1,
               toBeat + 0.000_1 >= minimum,
               durationNotation(toBeat, options: options).type != nil {
                result.append(toBeat)
                remaining -= toBeat
                cursor += toBeat
            }
        }

        let values = notationDurations(for: options).map(\.0).sorted(by: >)
        let minimum = values.min() ?? 0.0
        var safety = 0
        while remaining > 0.000_1 && safety < 32 {
            safety += 1
            if let exact = values.first(where: { abs($0 - remaining) < 0.02 }) {
                result.append(exact)
                remaining = 0
                break
            }
            if let piece = values.first(where: { $0 <= remaining + 0.000_1 }) {
                result.append(piece)
                remaining -= piece
                cursor += piece
            } else {
                if minimum > 0 && remaining < minimum - 0.000_1 {
                    if !result.isEmpty {
                        result[result.count - 1] += remaining
                    } else {
                        result.append(minimum)
                    }
                } else {
                    result.append(remaining)
                }
                remaining = 0
            }
        }
        return result
    }

    /// Zerlegt eine Pausendauer tickgenau in reguläre Werte.
    /// Wichtig: Die Summe darf niemals länger als die reale Lücke werden.
    private static func notationPieces(_ beats: Double, options: MusicXMLDisplayOptions) -> [Double] {
        var remainingTicks = max(0, Int((beats * Double(divisions)).rounded()))
        if remainingTicks == 0 { return [] }

        let valueTicks: [(Int, Double)] = notationDurations(for: options)
            .map { (max(1, Int(($0.0 * Double(divisions)).rounded())), $0.0) }
            .sorted { $0.0 > $1.0 }

        var result: [Double] = []
        var safety = 0
        while remainingTicks > 0 && safety < 64 {
            safety += 1
            if let choice = valueTicks.first(where: { $0.0 <= remainingTicks }) {
                result.append(choice.1)
                remainingTicks -= choice.0
            } else {
                // Ein Rest unterhalb der kleinsten Standarddauer wird nicht künstlich
                // verlängert. Er wird als exakter MusicXML-Rest ohne grafischen Typ
                // ausgegeben und kann daher den Takt nicht überfüllen.
                result.append(Double(remainingTicks) / Double(divisions))
                remainingTicks = 0
            }
        }
        return result
    }

    private static func tripletDurations() -> [(Double,String,Int)] {
        [
            (4.0/3.0, "half", 0),
            (2.0/3.0, "quarter", 0),
            (1.0/3.0, "eighth", 0),
            (1.0/6.0, "16th", 0),
            (1.0/12.0, "32nd", 0)
        ]
    }

    private static func straightNotationDurations(for options: MusicXMLDisplayOptions) -> [(Double,String,Int)] {
        guard effectiveRhythmMode(options) != "triplet" else { return [] }
        guard let minimum = effectiveStraightMinimum(options) else { return notationDurations }
        return notationDurations.filter { $0.0 + 0.000_1 >= minimum }
    }

    private static func tripletNotationDurations(for options: MusicXMLDisplayOptions) -> [(Double,String,Int)] {
        guard effectiveRhythmMode(options) != "straight" else { return [] }
        guard let minimum = effectiveTripletMinimum(options) else { return [] }
        return tripletDurations().filter { $0.0 + 0.000_1 >= minimum }
    }

    private static func notationDurations(for options: MusicXMLDisplayOptions) -> [(Double,String,Int)] {
        straightNotationDurations(for: options) + tripletNotationDurations(for: options)
    }

    private static func durationNotation(_ beats: Double, options: MusicXMLDisplayOptions)
        -> (type: String?, dots: Int, timeModification: (actual: Int, normal: Int)?) {
        if let c = tripletNotationDurations(for: options).min(by: { abs($0.0-beats) < abs($1.0-beats) }),
           abs(c.0-beats) < 0.02 {
            return (c.1, c.2, (3, 2))
        }
        if let c = straightNotationDurations(for: options).min(by: { abs($0.0-beats) < abs($1.0-beats) }),
           abs(c.0-beats) < 0.02 {
            return (c.1, c.2, nil)
        }
        return (nil, 0, nil)
    }


    private static func keyFifths(_ raw: String) -> Int {
        let s = raw.lowercased()
            .replacingOccurrences(of: "major", with: "")
            .replacingOccurrences(of: "minor", with: "")
            .replacingOccurrences(of: "-dur", with: "")
            .replacingOccurrences(of: "-moll", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let major: [String:Int] = ["c":0,"g":1,"d":2,"a":3,"e":4,"b":5,"h":5,"f#":6,"c#":7,
                                  "f":-1,"bb":-2,"b♭":-2,"eb":-3,"e♭":-3,"ab":-4,"a♭":-4,"db":-5,"d♭":-5,"gb":-6,"g♭":-6,"cb":-7,"c♭":-7]
        let minor: [String:Int] = ["a":0,"e":1,"b":2,"h":2,"f#":3,"c#":4,"g#":5,"d#":6,"a#":7,
                                  "d":-1,"g":-2,"c":-3,"f":-4,"bb":-5,"b♭":-5,"eb":-6,"e♭":-6,"ab":-7,"a♭":-7]
        let isMinor = raw.lowercased().contains("minor") || raw.lowercased().contains("moll")
        return (isMinor ? minor[s] : major[s]) ?? 0
    }

    private static func defaultClefSign(_ program: Int) -> String {
        // Cello/Bass-Familien bekommen Bassschlüssel; ansonsten Violinschlüssel.
        if (32...43).contains(program) { return "F" }
        return "G"
    }
    private static func defaultClefLine(_ program: Int) -> Int {
        defaultClefSign(program) == "F" ? 4 : 2
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func isoDate() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
