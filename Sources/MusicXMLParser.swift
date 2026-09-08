import Foundation

/// Importiert gebräuchliche MusicXML-Partituren (score-partwise) in das interne
/// Composition-Lab-Scoreformat. Noten, Stimmen/Backups, Taktart, Tempo, Tonart,
/// Instrumentname, MIDI-Programm und Klaviersysteme werden übernommen.
enum MusicXMLParserError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let s): return s }
    }
}

enum MusicXMLParser {
    static func parse(data: Data, fallbackTitle: String) throws -> Score {
        let delegate = Delegate(fallbackTitle: fallbackTitle)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            let msg = parser.parserError?.localizedDescription ?? "Unbekannter XML-Fehler."
            throw MusicXMLParserError.invalid("MusicXML konnte nicht gelesen werden: \(msg)")
        }
        return try delegate.makeScore()
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        struct PartInfo { var name: String = ""; var program: Int = 0 }
        struct NoteDraft {
            var start: Double = 0
            var duration: Double = 0
            var pitch: Int = 60
            var velocity: Int = 80
            var staff: Int = 0
            var chord = false
            var rest = false
            var grace = false
            var articulations: [String] = []
            var slurActions: [(type: String, number: String)] = []
        }

        struct DirectionDraft {
            var staff: Int? = nil
            var offsetUnits: Double = 0
            var dynamics: [String] = []
            var pedalActions: [String] = []
            var wedgeActions: [(type: String, number: String)] = []
        }

        let fallbackTitle: String
        var title = ""
        var bpm: Double = 120
        var ts = TimeSignature(n: 4, d: 4)
        var keyFifths: Int? = nil

        var partInfos: [String: PartInfo] = [:]
        var tracks: [String: Track] = [:]
        var partOrder: [String] = []

        var path: [String] = []
        var text = ""
        var currentPartID: String? = nil
        var currentScorePartID: String? = nil
        var divisions: Double = 1
        var measureStart: Double = 0
        var measureCursor: Double = 0
        var measureLength: Double { Double(ts.n) * 4.0 / Double(max(1, ts.d)) }
        var currentNote: NoteDraft? = nil
        var lastNoteStart: Double = 0
        var step = "C"
        var alter = 0
        var octave = 4
        var durationUnits: Double = 0
        var backupUnits: Double = 0
        var forwardUnits: Double = 0
        var currentVelocity: Int = 80
        var currentDirection: DirectionDraft? = nil
        var partEvents: [String: [NotationEvent]] = [:]
        var openWedges: [String: Int] = [:]
        var openSlurs: [String: Int] = [:]

        init(fallbackTitle: String) { self.fallbackTitle = fallbackTitle }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            path.append(elementName)
            text = ""

            switch elementName {
            case "score-part":
                currentScorePartID = attributeDict["id"]
                if let id = currentScorePartID { partInfos[id] = partInfos[id] ?? PartInfo() }
            case "part":
                if let id = attributeDict["id"] {
                    currentPartID = id
                    if !partOrder.contains(id) { partOrder.append(id) }
                    measureStart = 0
                    measureCursor = 0
                    divisions = 1
                }
            case "measure":
                measureCursor = 0
            case "note":
                currentNote = NoteDraft(velocity: currentVelocity)
                step = "C"; alter = 0; octave = 4; durationUnits = 0
            case "direction":
                currentDirection = DirectionDraft()
            case "chord": currentNote?.chord = true
            case "rest": currentNote?.rest = true
            case "grace": currentNote?.grace = true
            case "staccato", "tenuto", "accent":
                if currentNote != nil { currentNote?.articulations.append(elementName) }
            case "strong-accent":
                if currentNote != nil { currentNote?.articulations.append("marcato") }
            case "slur":
                if currentNote != nil, let kind = attributeDict["type"] {
                    currentNote?.slurActions.append((kind, attributeDict["number"] ?? "1"))
                }
            case "pedal":
                if currentDirection != nil, let kind = attributeDict["type"] {
                    currentDirection?.pedalActions.append(kind)
                }
            case "wedge":
                if currentDirection != nil, let kind = attributeDict["type"] {
                    currentDirection?.wedgeActions.append((kind, attributeDict["number"] ?? "1"))
                }
            case "p", "pp", "ppp", "pppp", "ppppp", "pppppp", "mp", "mf", "f", "ff", "fff", "ffff", "fffff", "ffffff", "sf", "sfp", "sfpp", "fp", "rf", "rfz", "sfz", "sffz", "fz":
                if currentDirection != nil, path.contains("dynamics") { currentDirection?.dynamics.append(elementName) }
            case "sound":
                if let s = attributeDict["tempo"], let v = Double(s), v > 0 { bpm = v }
                if let s = attributeDict["dynamics"], let v = Double(s) {
                    currentVelocity = min(127, max(1, Int((v * 1.27).rounded())))
                }
            case "backup": backupUnits = 0
            case "forward": forwardUnits = 0
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let parent = path.count >= 2 ? path[path.count - 2] : ""

            switch elementName {
            case "work-title", "movement-title":
                if title.isEmpty && !value.isEmpty { title = value }
            case "part-name":
                if let id = currentScorePartID {
                    var info = partInfos[id] ?? PartInfo(); info.name = value; partInfos[id] = info
                }
            case "midi-program":
                if let id = currentScorePartID, let v = Int(value) {
                    var info = partInfos[id] ?? PartInfo(); info.program = min(127, max(0, v - 1)); partInfos[id] = info
                }
            case "divisions":
                if let v = Double(value), v > 0 { divisions = v }
            case "beats":
                if let v = Int(value), v > 0 { ts.n = v }
            case "beat-type":
                if let v = Int(value), v > 0 { ts.d = v }
            case "fifths":
                if let v = Int(value) { keyFifths = v }
            case "per-minute":
                if let v = Double(value), v > 0 { bpm = v }
            case "step": if currentNote != nil { step = value.uppercased() }
            case "alter": if currentNote != nil { alter = Int(Double(value) ?? 0) }
            case "octave": if currentNote != nil { octave = Int(value) ?? 4 }
            case "staff":
                if currentNote != nil { currentNote?.staff = min(2, max(0, Int(value) ?? 0)) }
                else if currentDirection != nil { currentDirection?.staff = min(2, max(0, Int(value) ?? 0)) }
            case "offset":
                if currentDirection != nil { currentDirection?.offsetUnits = Double(value) ?? 0 }
            case "velocity":
                if currentNote != nil, let v = Double(value) { currentNote?.velocity = min(127, max(1, Int(v.rounded()))) }
            case "duration":
                if parent == "note" { durationUnits = Double(value) ?? 0 }
                else if parent == "backup" { backupUnits = Double(value) ?? 0 }
                else if parent == "forward" { forwardUnits = Double(value) ?? 0 }
            case "note":
                finishNote()
            case "direction":
                finishDirection()
            case "backup":
                measureCursor = max(0, measureCursor - backupUnits / max(1, divisions))
            case "forward":
                measureCursor += forwardUnits / max(1, divisions)
            case "measure":
                measureStart += max(measureLength, measureCursor)
                measureCursor = 0
            case "score-part": currentScorePartID = nil
            case "part": currentPartID = nil
            default: break
            }

            if !path.isEmpty { path.removeLast() }
            text = ""
        }

        private func finishNote() {
            guard var n = currentNote, let partID = currentPartID else { currentNote = nil; return }
            let dur = durationUnits / max(1, divisions)
            n.duration = n.grace ? max(0.125, dur) : max(0.001, dur)
            if n.chord { n.start = lastNoteStart } else { n.start = measureStart + measureCursor; lastNoteStart = n.start }

            if !n.rest {
                n.pitch = midiPitch(step: step, alter: alter, octave: octave)
                let info = partInfos[partID] ?? PartInfo()
                var tr = tracks[partID] ?? Track(nm: info.name.isEmpty ? "Spur \(partOrder.firstIndex(of: partID).map { $0 + 1 } ?? 1)" : info.name,
                                                   ch: min(15, partOrder.firstIndex(of: partID) ?? 0),
                                                   pg: info.program, nt: [], ct: nil, ev: nil)
                tr.nm = info.name.isEmpty ? tr.nm : info.name
                tr.pg = info.program
                tr.nt.append([n.start, n.duration, Double(n.pitch), Double(n.velocity), Double(n.staff), 0.95])
                tracks[partID] = tr

                for art in n.articulations {
                    addEvent(partID: partID, NotationEvent(b: n.start, t: "art", v: art, e: nil, st: n.staff > 0 ? n.staff : nil, p: n.pitch, n: nil))
                }
                for action in n.slurActions {
                    let key = rangeKey(partID: partID, staff: n.staff, number: action.number)
                    if action.type == "start" {
                        addEvent(partID: partID, NotationEvent(b: n.start, t: "slur", v: nil, e: nil, st: n.staff > 0 ? n.staff : nil, p: nil, n: nil))
                        openSlurs[key] = max(0, (partEvents[partID]?.count ?? 1) - 1)
                    } else if action.type == "stop" {
                        closeRange(partID: partID, key: key, at: n.start, open: &openSlurs)
                    }
                }
            }
            if !n.chord { measureCursor += dur }
            currentNote = nil
        }

        private func finishDirection() {
            guard let partID = currentPartID, let d = currentDirection else { currentDirection = nil; return }
            let beat = measureStart + measureCursor + d.offsetUnits / max(1, divisions)
            for dyn in d.dynamics {
                addEvent(partID: partID, NotationEvent(b: beat, t: "dyn", v: dyn, e: nil, st: d.staff, p: nil, n: nil))
            }
            for pedal in d.pedalActions {
                let value: String
                switch pedal { case "start": value = "start"; case "change": value = "change"; case "stop": value = "stop"; default: continue }
                addEvent(partID: partID, NotationEvent(b: beat, t: "pedal", v: value, e: nil, st: d.staff, p: nil, n: nil))
            }
            for wedge in d.wedgeActions {
                let key = rangeKey(partID: partID, staff: d.staff ?? 0, number: wedge.number)
                if wedge.type == "crescendo" || wedge.type == "diminuendo" {
                    addEvent(partID: partID, NotationEvent(b: beat, t: "wedge", v: wedge.type, e: nil, st: d.staff, p: nil, n: nil))
                    openWedges[key] = max(0, (partEvents[partID]?.count ?? 1) - 1)
                } else if wedge.type == "stop" {
                    closeRange(partID: partID, key: key, at: beat, open: &openWedges)
                }
            }
            currentDirection = nil
        }

        private func addEvent(partID: String, _ event: NotationEvent) {
            partEvents[partID, default: []].append(event)
        }

        private func rangeKey(partID: String, staff: Int, number: String) -> String {
            "\(partID):\(staff):\(number)"
        }

        private func closeRange(partID: String, key: String, at beat: Double, open: inout [String: Int]) {
            guard let index = open.removeValue(forKey: key), var events = partEvents[partID], index >= 0, index < events.count else { return }
            events[index].e = beat
            partEvents[partID] = events
        }

        func makeScore() throws -> Score {
            var out: [Track] = []
            for id in partOrder {
                if var tr = tracks[id], !tr.nt.isEmpty {
                    tr.nt.sort {
                        if abs($0[0] - $1[0]) > 0.000001 { return $0[0] < $1[0] }
                        return $0[2] < $1[2]
                    }
                    let events = partEvents[id] ?? []
                    tr.ev = events.isEmpty ? nil : events.sorted {
                        if abs($0.b - $1.b) > 0.000001 { return $0.b < $1.b }
                        return $0.t < $1.t
                    }
                    out.append(tr)
                }
            }
            guard !out.isEmpty else { throw MusicXMLParserError.invalid("Die MusicXML-Datei enthält keine lesbaren Noten.") }
            return Score(ti: title.isEmpty ? fallbackTitle : title,
                         bpm: bpm,
                         ts: ts,
                         k: keyName(fifths: keyFifths),
                         sm: "Importierte MusicXML-Vorlage mit \(out.count) Spur(en).",
                         tr: out)
        }

        private func midiPitch(step: String, alter: Int, octave: Int) -> Int {
            let pc: Int
            switch step { case "D": pc = 2; case "E": pc = 4; case "F": pc = 5; case "G": pc = 7; case "A": pc = 9; case "B": pc = 11; default: pc = 0 }
            return min(127, max(0, (octave + 1) * 12 + pc + alter))
        }

        private func keyName(fifths: Int?) -> String {
            guard let f = fifths else { return "" }
            let names = [-7:"C♭ major", -6:"G♭ major", -5:"D♭ major", -4:"A♭ major", -3:"E♭ major", -2:"B♭ major", -1:"F major", 0:"C major", 1:"G major", 2:"D major", 3:"A major", 4:"E major", 5:"B major", 6:"F♯ major", 7:"C♯ major"]
            return names[min(7, max(-7, f))] ?? ""
        }
    }
}
