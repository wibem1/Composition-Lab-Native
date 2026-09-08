import Foundation

struct StudioProBridgeDocument: Codable {
    struct Note: Codable {
        var start: Double
        var duration: Double
        var pitch: Int
        var velocity: Int
        var channel: Int?
        var selected: Bool?
        var muted: Bool?
    }

    struct BridgeTrack: Codable {
        var name: String?
        var channel: Int?
        var program: Int?
        var notes: [Note]?
    }

    var format: String
    var source: String?
    var title: String?
    var track_name: String?
    var bpm: Double?
    var time_signature: ReaperBridgeDocument.Meter?
    var track_count: Int?
    var note_count: Int?
    var tracks: [BridgeTrack]?
    var notes: [Note]?

    private func usableNotes(_ input: [Note]) -> [Note] {
        input.filter {
            !($0.muted ?? false) &&
            $0.duration > 0 &&
            (0...127).contains($0.pitch)
        }
    }

    func score() throws -> Score {
        let meter = time_signature ?? ReaperBridgeDocument.Meter(numerator: 4, denominator: 4)
        let scoreTempo = (bpm ?? 120) > 0 ? (bpm ?? 120) : 120
        let scoreTS = TimeSignature(n: meter.numerator > 0 ? meter.numerator : 4,
                                    d: meter.denominator > 0 ? meter.denominator : 4)

        // New multi-track bridge format (Studio Pro Bridge V0.5.6+):
        // preserve every selected Studio-Pro part as its own Composition Lab track.
        if let incomingTracks = tracks, !incomingTracks.isEmpty {
            var builtTracks: [Track] = []

            for (index, incoming) in incomingTracks.enumerated() {
                let usable = usableNotes(incoming.notes ?? [])
                if usable.isEmpty { continue }

                let channel = max(0, min(15, incoming.channel ?? index))
                let program = max(0, min(127, incoming.program ?? 0))
                let name = (incoming.name?.isEmpty == false)
                    ? incoming.name!
                    : "Studio Pro \(index + 1)"

                let nt = usable
                    .sorted { $0.start == $1.start ? $0.pitch < $1.pitch : $0.start < $1.start }
                    .map {
                        [$0.start,
                         $0.duration,
                         Double($0.pitch),
                         Double(max(1, min(127, $0.velocity))),
                         0.0,
                         0.95]
                    }

                builtTracks.append(
                    Track(nm: name, ch: channel, pg: program, nt: nt, ct: nil, ev: nil)
                )
            }

            guard !builtTracks.isEmpty else {
                throw NSError(domain: "CompositionLab.StudioProBridge",
                              code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Die ausgewählten Studio-Pro-MIDI-Clips enthalten keine verwendbaren Noten."])
            }

            let baseTitle: String
            if let title, !title.isEmpty {
                baseTitle = title
            } else if builtTracks.count == 1 {
                baseTitle = builtTracks[0].nm
            } else {
                baseTitle = "Studio Pro – \(builtTracks.count) Spuren"
            }

            return Score(
                ti: baseTitle,
                bpm: scoreTempo,
                ts: scoreTS,
                k: "",
                sm: "Direkt aus \(builtTracks.count) ausgewählten Studio-Pro-MIDI-Clips übernommen.",
                tr: builtTracks
            )
        }

        // Backward-compatible one-track format used by the proven older bridge.
        let usable = usableNotes(notes ?? [])
        guard !usable.isEmpty else {
            throw NSError(domain: "CompositionLab.StudioProBridge",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Die Studio-Pro-Vorlage enthält keine verwendbaren Noten."])
        }

        let groups = Dictionary(grouping: usable,
                                by: { max(0, min(15, $0.channel ?? 0)) })

        let baseName = (track_name?.isEmpty == false ? track_name! : "Studio Pro")
        let builtTracks = groups.keys.sorted().map { ch -> Track in
            let nt = groups[ch]!
                .sorted { $0.start == $1.start ? $0.pitch < $1.pitch : $0.start < $1.start }
                .map {
                    [$0.start,
                     $0.duration,
                     Double($0.pitch),
                     Double(max(1, min(127, $0.velocity))),
                     0.0,
                     0.95]
                }
            let suffix = groups.count > 1 ? " · Kanal \(ch + 1)" : ""
            return Track(nm: baseName + suffix, ch: ch, pg: 0, nt: nt, ct: nil, ev: nil)
        }

        return Score(
            ti: baseName,
            bpm: scoreTempo,
            ts: scoreTS,
            k: "",
            sm: "Direkt aus einem ausgewählten Studio-Pro-MIDI-Clip übernommen.",
            tr: builtTracks
        )
    }
}

enum StudioProBridge {
    static let fileName = "CompositionLab_StudioPro_Bridge.json"
    static let returnMIDIFileName = "CompositionLab_Return.mid"
    static let returnJSONFileName = "CompositionLab_Return.json"

    /// Studio Pro's $USERCONTENT location is intentionally not assumed.
    /// We search the user's Documents tree for the single bridge filename.
    static func fileURL() -> URL? {
        let fm = FileManager.default
        let documents = fm.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        guard let e = fm.enumerator(at: documents,
                                    includingPropertiesForKeys: [.contentModificationDateKey],
                                    options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }

        var newest: (URL, Date)?
        for case let url as URL in e {
            if url.lastPathComponent != fileName { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values?.contentModificationDate ?? .distantPast
            if newest == nil || date > newest!.1 {
                newest = (url, date)
            }
        }
        return newest?.0
    }

    /// Writes the current Composition Lab MIDI result next to Studio Pro's
    /// inbound bridge file, i.e. inside Studio Pro's permitted $USERCONTENT area.
    static func writeReturnMIDI(_ data: Data) throws {
        guard let bridgeURL = fileURL() else {
            // No Studio-Pro bridge has been used yet; return export is simply unavailable.
            return
        }
        let url = bridgeURL.deletingLastPathComponent().appendingPathComponent(returnMIDIFileName)
        try data.write(to: url, options: .atomic)
    }

    /// Writes a deliberately simple, object-based return document for Studio Pro.
    /// We avoid Score.nt's nested numeric arrays here because Studio Pro's internal
    /// JSON bridge proved unreliable with that representation.
    static func writeReturnScore(_ score: Score) throws {
        guard let bridgeURL = fileURL() else { return }
        let url = bridgeURL.deletingLastPathComponent().appendingPathComponent(returnJSONFileName)

        let tracks: [[String: Any]] = score.tr.map { track in
            let notes: [[String: Any]] = track.nt.compactMap { a in
                guard a.count >= 4 else { return nil }
                return [
                    "start": a[0],
                    "duration": a[1],
                    "pitch": Int(a[2].rounded()),
                    "velocity": Int(a[3].rounded()),
                    "channel": track.ch
                ]
            }
            return [
                "name": track.nm,
                "channel": track.ch,
                "program": track.pg,
                "notes": notes
            ]
        }

        let totalNotes = tracks.reduce(0) { partial, track in
            partial + ((track["notes"] as? [[String: Any]])?.count ?? 0)
        }

        let document: [String: Any] = [
            "format": "CompositionLab-StudioPro-Return-0.4",
            "source": "Composition Lab",
            "title": score.ti,
            "bpm": score.bpm,
            "time_signature": [
                "numerator": score.ts.n,
                "denominator": score.ts.d
            ],
            "note_count": totalNotes,
            "tracks": tracks
        ]

        let data = try JSONSerialization.data(withJSONObject: document, options: [])
        try data.write(to: url, options: .atomic)
    }

    static func modificationDate() -> Date? {
        guard let url = fileURL() else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    static func loadScore() throws -> Score {
        guard let url = fileURL() else {
            throw NSError(domain: "CompositionLab.StudioProBridge",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Keine Studio-Pro-Übergabedatei gefunden."])
        }
        let data = try Data(contentsOf: url)
        let doc = try JSONDecoder().decode(StudioProBridgeDocument.self, from: data)
        guard doc.format.hasPrefix("CompositionLab-StudioPro-Bridge-") else {
            throw NSError(domain: "CompositionLab.StudioProBridge",
                          code: 3,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Unbekanntes Studio-Pro-Übergabeformat."])
        }
        return try doc.score()
    }
}
