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
            return [
                ("claude-fable-5-1", "Claude Fable 5.1"),
                ("claude-sonnet-5", "Claude Sonnet 5")
            ]
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
            switch model {
            case "claude-fable-5-1": rates = (10.00, 50.00)
            default: rates = (2.00, 10.00) // Claude Sonnet 5
            }
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
    // Eingefrorener musikalischer Kern: entspricht Engine Build 14 der APK/iPad-Version.
    static let engineBuild = 14

    static let system = """
    Du bist ein Kompositions- und Produktionsassistent für MIDI.
    Erfinde selbständige, geschlossene Musik nach dem Auftrag des Nutzers. Achte auf Stimmführung, Dynamik (Velocity 1-127), Rhythmik und Artikulation.
    """

    static func conceptPrompt(_ assignment: String) -> String {
        """
        Formuliere ausschließlich einen kurzen musikalischen Gedanken/Impuls für folgenden Auftrag:

        \(assignment)

        WICHTIG FÜR DIESEN SCHRITT:
        - Nur die musikalische Idee in normaler Sprache beschreiben.
        - Keine technische Umsetzung liefern.
        - Kein JSON ausgeben.
        - Keinen Python-Code oder anderen Programmcode ausgeben.
        - Keinen MIDI-Code, keine Bibliotheken und keine Codeblöcke ausgeben.
        - Noch keine Partitur erzeugen.

        Antworte ausschließlich mit dem musikalischen Impuls.
        """
    }

    static let technical = """
    NOTATION UND AUSGABE:
    - "d" = Notierter Wert in Viertelnoten-Beats (0.125, 0.25, 0.333333, 0.5, 0.666667, 0.75, 1, 1.5, 2, 3, 4, 6, 8).
    - "g" = Gate/Klingdauer als Faktor (z.B. 0.95 = normal, 0.5 = staccato, 1.05 = legato).
    - "st" = System (0=Standard, 1=Rechte Hand / oberes System, 2=Linke Hand / unteres System).
    - Format: JSON mit folgender Struktur:
    {
      "ti": "Titel",
      "bpm": 96,
      "ts": {"n": 4, "d": 4},
      "k": "e minor",
      "sm": "Kurze Zusammenfassung",
      "tr": [
        {
          "nm": "Piano",
          "ch": 0,
          "pg": 0,
          "nt": [[0.0, 1.0, 60, 80, 1]],
          "ct": [[0.0, 64, 0]],
          "me": [{"b":0.0,"m":"B0 01 40"}]
        }
      ]
    }
    nt-Array: [StartBeat, Dauer, Pitch, Velocity, Staff, Gate] (Gate ist optional, Standard 0.95).
    ct-Array: [Beat, CC, Wert].
    me-Array (optional): rohe Nicht-Noten-MIDI-Ereignisse für verlustfreie DAW-Übergabe.
    Format: {"b": Beat, "m": "HEX-BYTES", "selected": true/false, "muted": true/false}.
    Dazu gehören insbesondere alle CC, Program Change, Pitch Bend, Channel Pressure,
    Poly Aftertouch sowie ggf. SysEx/Meta-/CCBZ-Ereignisse.
    WICHTIG: Wenn eine geladene Vorlage "me"-Ereignisse enthält, diese bei Bearbeitungen
    grundsätzlich unverändert erhalten, sofern der Nutzer nicht ausdrücklich ihre Änderung verlangt.

    OPTIONALE NOTATIONS-/AUSDRUCKSEREIGNISSE:
    Jede Spur darf zusätzlich ein "ev"-Array enthalten. Diese Angaben dienen der Partitur/MusicXML und sind optional.
    Format eines Ereignisses:
    {"b": Beat, "t": Typ, "v": Wert, "e": EndBeat, "st": Staff, "p": MIDI-Pitch, "n": BPM}
    Nur benötigte Felder angeben.

    Erlaubte Typen:
    - "dyn": explizite Dynamik, v = "pp","p","mp","mf","f","ff","sf","sfz","fp"
      Beispiel: {"b":0,"t":"dyn","v":"p","st":1}
    - "art": Artikulation auf einer Note, v = "staccato","tenuto","accent","marcato","fermata";
      optional p und st zur eindeutigen Zuordnung
      Beispiel: {"b":4,"t":"art","v":"accent","p":67,"st":1}
    - "orn": Ornament auf einer Note. Erlaubte Werte:
      * "trill": Triller. Bei einem musikalisch beabsichtigten Triller IMMER zusätzlich dieses Ereignis setzen,
        auch wenn der Triller für die MIDI-Wiedergabe als schnelle Wechselnoten ausnotiert wird.
        b = Beginn, e = Ende; optional p und st.
        Beispiel: {"b":12,"t":"orn","v":"trill","e":14,"p":72,"st":1}
      * "acciaccatura": kurzer Vorschlag / durchgestrichene Vorschlagnote.
        Das Ereignis kennzeichnet DIE kurze Vorschlagnote selbst über b, p und optional st.
        Beispiel: {"b":20,"t":"orn","v":"acciaccatura","p":74,"st":1}
      * "appoggiatura": nicht durchgestrichene Vorschlagnote.
        Das Ereignis kennzeichnet DIE Vorschlagnote selbst über b, p und optional st.
        Beispiel: {"b":24,"t":"orn","v":"appoggiatura","p":69,"st":1}
    - "pedal": musikalisch beabsichtigtes Haltepedal, v = "start","change" oder "stop".
      "start" = Pedal niederdrücken, "change" = an dieser Stelle kurz lösen und sofort neu nehmen,
      "stop" = Pedal vollständig lösen.
      Beispiele:
      {"b":0,"t":"pedal","v":"start"}
      {"b":2,"t":"pedal","v":"change"}
      {"b":4,"t":"pedal","v":"stop"}
      PEDALREGELN:
      * Pedal bewusst nach Harmonie und Phrasierung setzen, nicht pauschal über lange Abschnitte halten.
      * Bei deutlichem Harmoniewechsel in der Regel "change" setzen.
      * Bei Staccato, trockener Artikulation und klaren Pausen sparsam oder gar nicht pedalieren.
      * Ein Pedalabschnitt soll nur so lange dauern, wie die Klangmischung musikalisch sinnvoll bleibt.
      * Wenn semantische "pedal"-Ereignisse verwendet werden, KEINE CC64-Ereignisse dafür zusätzlich in "ct" ausgeben.
    - "wedge": Crescendo/Diminuendo-Gabel, v = "crescendo" oder "diminuendo", e = EndBeat
      Beispiel: {"b":8,"t":"wedge","v":"crescendo","e":12,"st":1}
    - "tempo": Tempo-/Agogikangabe, v z.B. "accelerando","ritardando","a tempo";
      optional n = neues/erreichtes Tempo in BPM
      Beispiel: {"b":16,"t":"tempo","v":"ritardando","n":72}
    - "slur": Phrasierungsbogen von b bis e, optional st
      Beispiel: {"b":20,"t":"slur","e":24,"st":1}
    - "words": freie Spiel-/Ausdrucksanweisung, v z.B. "dolce","espressivo","cantabile"
      Beispiel: {"b":28,"t":"words","v":"dolce","st":1}

    WICHTIG:
    - ev nur setzen, wenn die Angabe musikalisch beabsichtigt ist.
    - Triller als musikalisches Ornament erkennen und mit t="orn", v="trill" kennzeichnen.
    - Vorschlagnoten erkennen und als t="orn" mit v="acciaccatura" oder v="appoggiatura" kennzeichnen.
      Eine bloß kurze normale Note ist KEINE Vorschlagnote; nur musikalisch beabsichtigte Vorschläge markieren.
    - Pedal musikalisch nach Harmonie und Phrasierung planen; lange undifferenzierte Pedalflächen vermeiden.
    - Nicht aus Velocity automatisch Dynamikzeichen ableiten.
    - Nicht aus Gate automatisch Artikulation ableiten.
    - Globale Tempo-/Formangaben möglichst nur in der ersten Spur notieren, damit sie in der Partitur nicht mehrfach erscheinen.

    Gib ausschließlich valides JSON aus.
    """
}
