import Foundation

enum Provider: String, CaseIterable, Codable {
    case gemini, anthropic, openai

    var displayName: String {
        switch self {
        case .gemini: return "Google / Gemini"
        case .anthropic: return "Anthropic / Claude"
        case .openai: return "OpenAI"
        }
    }

    var models: [(String, String)] {
        switch self {
        case .gemini:
            return [("gemini-3.7-flash", "Gemini 3.7 Flash")]
        case .anthropic:
            return [("claude-sonnet-5", "Claude Sonnet 5")]
        case .openai:
            return [
                ("gpt-5.6-sol", "GPT-5.6 Sol"),
                ("gpt-5.6-terra", "GPT-5.6 Terra"),
                ("gpt-5.6-luna", "GPT-5.6 Luna")
            ]
        }
    }
}

enum Effort: String, CaseIterable, Codable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: return "Sparsam – Low"
        case .medium: return "Standard – Medium"
        case .high: return "Maximum – High"
        }
    }
}

struct TimeSignature: Codable {
    var n: Int
    var d: Int
}

struct NotationEvent: Codable {
    /// Beat position in quarter-note beats.
    var b: Double
    /// Type: dyn, art, orn, pedal, wedge, tempo, slur, words
    var t: String
    /// Text/value, e.g. p, accent, crescendo, ritardando, dolce.
    var v: String?
    /// Optional end beat, used by wedge/slur.
    var e: Double?
    /// Optional staff number (1/2 for piano).
    var st: Int?
    /// Optional MIDI pitch for note-specific articulation.
    var p: Int?
    /// Optional numeric tempo in BPM.
    var n: Double?
}

/// Generic non-note MIDI event preserved losslessly enough for DAW round-trips.
/// `b` is the musical beat position; `m` contains the complete raw MIDI message as hex.
/// Examples: B0 01 7F (CC1), C0 28 (Program Change), E0 00 40 (Pitch Bend center).
struct RawMIDIEvent: Codable {
    var b: Double
    var m: String
    var selected: Bool?
    var muted: Bool?
}

struct Track: Codable {
    var nm: String
    var ch: Int
    var pg: Int
    var nt: [[Double]]
    var ct: [[Double]]?
    /// Optional notation/expression events. Old scores without this field remain valid.
    var ev: [NotationEvent]?
    /// Optional raw non-note MIDI events for DAW round-trips (CC, program,
    /// pitch bend, channel/poly pressure, SysEx/meta events, REAPER CCBZ data).
    var me: [RawMIDIEvent]? = nil
}

struct Score: Codable {
    var ti: String
    var bpm: Double
    var ts: TimeSignature
    var k: String
    var sm: String
    var tr: [Track]
}

enum HistoryArea: String, Codable {
    case composition
    case experiment
    case comparison
}

struct HistoryItem: Codable {
    var id: UUID
    var time: Date
    var title: String
    var provider: Provider
    var model: String
    var concept: String
    var score: Score
    var costUSD: Double? = nil
    var inputTokens: Int? = nil
    var outputTokens: Int? = nil

    /// Herkunft des Verlaufseintrags. Bei alten gespeicherten Verläufen fehlt
    /// dieses Feld; solche Einträge gelten aus Kompatibilitätsgründen als Composer-Einträge.
    var area: HistoryArea? = nil

    var effectiveArea: HistoryArea { area ?? .composition }
}

struct APICost {
    static func estimate(provider: Provider, model: String, inputTokens: Int, outputTokens: Int) -> Double {
        let rates: (input: Double, output: Double)
        switch provider {
        case .gemini:
            // Gemini 3.7 Flash: introductory paid-tier pricing through 2026-12-31.
            rates = (0.75, 3.75)
        case .anthropic:
            // Claude Sonnet 5.
            rates = (2.00, 10.00)
        case .openai:
            switch model {
            case "gpt-5.6-terra": rates = (2.00, 12.00)
            case "gpt-5.6-luna": rates = (0.20, 1.20)
            default: rates = (4.00, 20.00) // GPT-5.6 Sol
            }
        }
        return (Double(inputTokens) * rates.input + Double(outputTokens) * rates.output) / 1_000_000.0
    }

    static func display(_ value: Double) -> String {
        if value < 0.01 { return String(format: "$%.5f", value) }
        if value < 1.0 { return String(format: "$%.4f", value) }
        return String(format: "$%.2f", value)
    }
}

enum NotationPreset: String, Codable, CaseIterable {
    case readablePiano
    case midiNear
    case custom

    var displayName: String {
        switch self {
        case .readablePiano: return "Klavier – lesbar"
        case .midiNear: return "MIDI-nah"
        case .custom: return "Benutzerdefiniert"
        }
    }
}

/// Persistentes Darstellungsprofil für den MusicXML-Notensatz.
/// Es verändert niemals MIDI oder den internen Score.
struct NotationProfile: Codable, Equatable {
    var version: Int = 1
    var preset: NotationPreset = .readablePiano
    var options: MusicXMLDisplayOptions = .readablePiano

    static let readablePiano = NotationProfile(
        version: 1, preset: .readablePiano, options: .readablePiano
    )

    static let midiNear = NotationProfile(
        version: 1, preset: .midiNear, options: .midiNear
    )
}

struct AppSettings: Codable {
    var provider: Provider = .anthropic
    var models: [String:String] = [:]
    var efforts: [String:String] = [:]
    var measures: String = ""
    var meter: String = ""
    var tempo: String = ""
    var key: String = ""
    var ensemble: String = ""
    var prompt: String = "Komponiere ein eigenständiges, musikalisch überzeugendes Stück."
    var zoomPercent: Int? = nil
}

enum ComposerPrompts {
    static let engineBuild = 22

    static let system = """
    Du bist ein eigenständiger Komponist.
    """

    static func conceptPrompt(_ assignment: String) -> String {
        """
        Entwickle zunächst deine eigene musikalische Vorstellung zu diesem Kompositionsauftrag:

        \(assignment)

        In diesem Schritt noch keine technische Ausgabe: kein JSON, MIDI, MusicXML, LilyPond,
        ABC oder Programmcode. Antworte nur mit deiner musikalischen Vorstellung.
        """
    }

    static let technical = """
    TECHNISCHES AUSGABEFORMAT

    Gib die bereits komponierte Musik ausschließlich als valides JSON in dieser Struktur aus:
    {
      "ti": "Titel",
      "bpm": 96,
      "ts": {"n": 4, "d": 4},
      "k": "e minor",
      "sm": "Kurze Zusammenfassung",
      "tr": [{"nm":"Piano","ch":0,"pg":0,"nt":[[0.0,1.0,60,80,1,0.95]],"ct":[],"ev":[],"me":[]}]
    }

    TECHNISCHE BEDEUTUNG
    - nt: [StartBeat, DauerInViertelnoten, MIDIPitch, Velocity, Staff, Gate].
      Staff: 0=Standard, 1=oberes System, 2=unteres System. Gate ist optional; Standard 0.95.
    - ct: [Beat, CC, Wert].
    - me: optionale rohe Nicht-Noten-MIDI-Ereignisse als
      {"b":Beat,"m":"HEX-BYTES","selected":true/false,"muted":true/false}.
      Vorhandene me-Ereignisse einer geladenen Vorlage unverändert erhalten, sofern der Nutzer nicht ihre Änderung verlangt.
    - ev: optionale Notations-/Ausdrucksereignisse als
      {"b":Beat,"t":Typ,"v":Wert,"e":EndBeat,"st":Staff,"p":MIDIPitch,"n":BPM}.
      Nur tatsächlich in der komponierten Musik vorhandene Angaben kodieren.
      Typen: dyn, art, orn, pedal, wedge, tempo, slur, words.
      dyn: pp,p,mp,mf,f,ff,sf,sfz,fp
      art: staccato,tenuto,accent,marcato,fermata
      orn: trill,acciaccatura,appoggiatura
      pedal: start,change,stop
      wedge: crescendo,diminuendo
      Bei semantischen pedal-Ereignissen dasselbe Pedal nicht zusätzlich als CC64 in ct kodieren.

    Die technischen Felder beschreiben die Musik; sie geben keine musikalischen Entscheidungen vor.
    Gib ausschließlich das JSON-Objekt aus.
    """
}
