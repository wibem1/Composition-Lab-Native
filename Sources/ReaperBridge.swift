import Foundation

struct ReaperBridgeDocument: Codable {
    struct Meter: Codable { var numerator: Int; var denominator: Int }
    struct Note: Codable {
        var start: Double
        var duration: Double
        var pitch: Int
        var velocity: Int
        var channel: Int
        var selected: Bool?
        var muted: Bool?
    }
    struct MIDIEvent: Codable {
        var beat: Double
        var message: String
        var selected: Bool?
        var muted: Bool?
    }
    struct BridgeTrack: Codable {
        var name: String
        var channel: Int?
        var program: Int?
        var notes: [Note]
        var midi_events: [MIDIEvent]?
    }

    var format: String
    var source: String
    var title: String?
    var bpm: Double
    var time_signature: Meter
    var track_count: Int?
    var note_count: Int?
    var tracks: [BridgeTrack]?

    // Backward compatibility with V0.5.x.
    var track_name: String?
    var notes: [Note]?

    func score() throws -> Score {
        let meter = TimeSignature(n: time_signature.numerator > 0 ? time_signature.numerator : 4,
                                  d: time_signature.denominator > 0 ? time_signature.denominator : 4)
        let tempo = bpm > 0 ? bpm : 120

        if let incoming = tracks, !incoming.isEmpty {
            var out: [Track] = []
            for (index, tr) in incoming.enumerated() {
                let usable = tr.notes.filter {
                    !($0.muted ?? false) && $0.duration > 0 && (0...127).contains($0.pitch)
                }
                let nt = usable.sorted {
                    $0.start == $1.start ? $0.pitch < $1.pitch : $0.start < $1.start
                }.map {
                    [$0.start, $0.duration, Double($0.pitch),
                     Double(max(1,min(127,$0.velocity))), 0.0, 0.95]
                }
                let raw = (tr.midi_events ?? []).map {
                    RawMIDIEvent(b: $0.beat, m: $0.message,
                                 selected: $0.selected, muted: $0.muted)
                }
                if !nt.isEmpty || !raw.isEmpty {
                    out.append(Track(nm: tr.name.isEmpty ? "REAPER \(index+1)" : tr.name,
                                     ch: max(0,min(15,tr.channel ?? index)),
                                     pg: max(0,min(127,tr.program ?? 0)),
                                     nt: nt, ct: nil, ev: nil,
                                     me: raw.isEmpty ? nil : raw))
                }
            }
            guard !out.isEmpty else {
                throw NSError(domain:"CompositionLab.ReaperBridge", code:1,
                              userInfo:[NSLocalizedDescriptionKey:"Die REAPER-Auswahl enthält keine verwendbaren MIDI-Daten."])
            }
            return Score(ti: (title?.isEmpty == false ? title! : (out.count == 1 ? out[0].nm : "REAPER – \(out.count) Spuren")),
                         bpm: tempo, ts: meter, k: "",
                         sm: "Direkt aus \(out.count) ausgewählten REAPER-MIDI-Clips übernommen – einschließlich Nicht-Noten-MIDI-Ereignissen.",
                         tr: out)
        }

        let oldNotes = notes ?? []
        let usable = oldNotes.filter {
            !($0.muted ?? false) && $0.duration > 0 && (0...127).contains($0.pitch)
        }
        guard !usable.isEmpty else {
            throw NSError(domain:"CompositionLab.ReaperBridge", code:1,
                          userInfo:[NSLocalizedDescriptionKey:"Die REAPER-Vorlage enthält keine verwendbaren Noten."])
        }
        let groups = Dictionary(grouping: usable, by: { max(0,min(15,$0.channel)) })
        let name = (track_name?.isEmpty == false ? track_name! : "REAPER")
        let out = groups.keys.sorted().map { ch -> Track in
            let nt = groups[ch]!.sorted {
                $0.start == $1.start ? $0.pitch < $1.pitch : $0.start < $1.start
            }.map {
                [$0.start,$0.duration,Double($0.pitch),
                 Double(max(1,min(127,$0.velocity))),0.0,0.95]
            }
            return Track(nm: groups.count > 1 ? "\(name) · Kanal \(ch+1)" : name,
                         ch: ch, pg: 0, nt: nt, ct: nil, ev: nil, me: nil)
        }
        return Score(ti:name,bpm:tempo,ts:meter,k:"",
                     sm:"Direkt aus einem ausgewählten REAPER-MIDI-Clip übernommen.",tr:out)
    }
}

enum ReaperBridge {
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/REAPER/Composition Lab/reaper_selected_midi.json")
    }
    static func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate]) as? Date
    }
    static func loadScore() throws -> Score {
        let data = try Data(contentsOf: fileURL)
        let doc = try JSONDecoder().decode(ReaperBridgeDocument.self, from: data)
        guard doc.source == "REAPER" else {
            throw NSError(domain:"CompositionLab.ReaperBridge", code:2,
                          userInfo:[NSLocalizedDescriptionKey:"Unbekannte Übergabequelle."])
        }
        return try doc.score()
    }
}

struct ReaperBridgeResultDocument: Codable {
    struct Meter: Codable { var numerator: Int; var denominator: Int }
    struct Note: Codable {
        var start: Double
        var duration: Double
        var pitch: Int
        var velocity: Int
        var channel: Int
    }
    struct MIDIEvent: Codable {
        var beat: Double
        var message: String
        var selected: Bool?
        var muted: Bool?
    }
    struct ResultTrack: Codable {
        var name: String
        var channel: Int
        var program: Int
        var notes: [Note]
        var midi_events: [MIDIEvent]
    }

    var format: String
    var source: String
    var title: String
    var bpm: Double
    var time_signature: Meter
    var tracks: [ResultTrack]

    init(score: Score) {
        format = "CompositionLab-Reaper-Result-0.6"
        source = "Composition Lab"
        title = score.ti
        bpm = score.bpm
        time_signature = Meter(numerator: score.ts.n, denominator: score.ts.d)
        tracks = score.tr.map { track in
            let notes = track.nt.compactMap { n -> Note? in
                guard n.count >= 4 else { return nil }
                let pitch = Int(n[2].rounded()), velocity = Int(n[3].rounded())
                guard n[1] > 0, (0...127).contains(pitch) else { return nil }
                return Note(start:n[0], duration:n[1], pitch:pitch,
                            velocity:max(1,min(127,velocity)),
                            channel:max(0,min(15,track.ch)))
            }
            var events = (track.me ?? []).map {
                MIDIEvent(beat:$0.b, message:$0.m,
                          selected:$0.selected, muted:$0.muted)
            }

            // Ensure a track program exists even for newly generated Composition Lab music.
            // Do not duplicate a preserved Program Change at beat 0.
            let hasInitialProgram = events.contains { ev in
                guard ev.beat == 0 else { return false }
                let first = ev.message.split(separator:" ").first.flatMap { UInt8($0, radix:16) }
                return first.map { ($0 & 0xF0) == 0xC0 } ?? false
            }
            if !hasInitialProgram {
                let status = 0xC0 | max(0,min(15,track.ch))
                let program = max(0,min(127,track.pg))
                events.append(MIDIEvent(beat:0,
                                        message:String(format:"%02X %02X",status,program),
                                        selected:false, muted:false))
            }
            events.sort { $0.beat < $1.beat }

            return ResultTrack(name:track.nm, channel:track.ch, program:track.pg,
                               notes:notes, midi_events:events)
        }
    }
}

extension ReaperBridge {
    static var resultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/REAPER/Composition Lab/composition_lab_result.json")
    }
    static func writeResult(score: Score) throws {
        let dir = resultFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let doc = ReaperBridgeResultDocument(score: score)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(doc).write(to: resultFileURL, options:.atomic)
    }
}
