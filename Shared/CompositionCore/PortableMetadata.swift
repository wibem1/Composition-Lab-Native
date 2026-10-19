import Foundation

/// JSON extension fields retained verbatim in meaning when older clients read a
/// newer CLAB/project. They are flattened back into the original record, never
/// moved under a private metadata key. No provider secrets belong here.
enum JSONValue: Codable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

struct RecordKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

extension HistoryItem {
    private static let recordFields: Set<String> = ["id", "time", "title", "provider", "model", "concept", "score", "costUSD", "inputTokens", "outputTokens", "area"]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RecordKey.self)
        id = try c.decode(UUID.self, forKey: RecordKey("id"))
        time = try c.decode(Date.self, forKey: RecordKey("time"))
        title = try c.decode(String.self, forKey: RecordKey("title"))
        provider = try c.decode(Provider.self, forKey: RecordKey("provider"))
        model = try c.decode(String.self, forKey: RecordKey("model"))
        concept = try c.decode(String.self, forKey: RecordKey("concept"))
        score = try c.decode(Score.self, forKey: RecordKey("score"))
        costUSD = try c.decodeIfPresent(Double.self, forKey: RecordKey("costUSD"))
        inputTokens = try c.decodeIfPresent(Int.self, forKey: RecordKey("inputTokens"))
        outputTokens = try c.decodeIfPresent(Int.self, forKey: RecordKey("outputTokens"))
        area = try c.decodeIfPresent(HistoryArea.self, forKey: RecordKey("area"))
        extraFields = [:]
        for key in c.allKeys where !Self.recordFields.contains(key.stringValue) {
            extraFields[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: RecordKey.self)
        try c.encode(id, forKey: RecordKey("id"))
        try c.encode(time, forKey: RecordKey("time"))
        try c.encode(title, forKey: RecordKey("title"))
        try c.encode(provider, forKey: RecordKey("provider"))
        try c.encode(model, forKey: RecordKey("model"))
        try c.encode(concept, forKey: RecordKey("concept"))
        try c.encode(score, forKey: RecordKey("score"))
        try c.encodeIfPresent(costUSD, forKey: RecordKey("costUSD"))
        try c.encodeIfPresent(inputTokens, forKey: RecordKey("inputTokens"))
        try c.encodeIfPresent(outputTokens, forKey: RecordKey("outputTokens"))
        try c.encodeIfPresent(area, forKey: RecordKey("area"))
        for (name, value) in extraFields where !Self.recordFields.contains(name) { try c.encode(value, forKey: RecordKey(name)) }
    }
}

extension CompositionLabDocument {
    private static let recordFields: Set<String> = ["format", "version", "savedAt", "title", "score", "concept", "provider", "model", "measures", "meter", "tempo", "musicalKey", "ensemble", "assignment", "sourceName", "sourceScore", "midiData", "musicXMLData", "originalMusicXMLData", "costUSD", "inputTokens", "outputTokens"]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RecordKey.self)
        format = try c.decode(String.self, forKey: RecordKey("format"))
        version = try c.decode(Int.self, forKey: RecordKey("version"))
        savedAt = try c.decode(Date.self, forKey: RecordKey("savedAt"))
        title = try c.decode(String.self, forKey: RecordKey("title"))
        score = try c.decode(Score.self, forKey: RecordKey("score"))
        concept = try c.decode(String.self, forKey: RecordKey("concept"))
        provider = try c.decodeIfPresent(Provider.self, forKey: RecordKey("provider"))
        model = try c.decodeIfPresent(String.self, forKey: RecordKey("model"))
        measures = try c.decode(String.self, forKey: RecordKey("measures"))
        meter = try c.decode(String.self, forKey: RecordKey("meter"))
        tempo = try c.decode(String.self, forKey: RecordKey("tempo"))
        musicalKey = try c.decode(String.self, forKey: RecordKey("musicalKey"))
        ensemble = try c.decode(String.self, forKey: RecordKey("ensemble"))
        assignment = try c.decode(String.self, forKey: RecordKey("assignment"))
        sourceName = try c.decodeIfPresent(String.self, forKey: RecordKey("sourceName"))
        sourceScore = try c.decodeIfPresent(Score.self, forKey: RecordKey("sourceScore"))
        midiData = try c.decodeIfPresent(Data.self, forKey: RecordKey("midiData"))
        musicXMLData = try c.decodeIfPresent(Data.self, forKey: RecordKey("musicXMLData"))
        originalMusicXMLData = try c.decodeIfPresent(Data.self, forKey: RecordKey("originalMusicXMLData"))
        costUSD = try c.decodeIfPresent(Double.self, forKey: RecordKey("costUSD"))
        inputTokens = try c.decodeIfPresent(Int.self, forKey: RecordKey("inputTokens"))
        outputTokens = try c.decodeIfPresent(Int.self, forKey: RecordKey("outputTokens"))
        extraFields = [:]
        for key in c.allKeys where !Self.recordFields.contains(key.stringValue) {
            extraFields[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: RecordKey.self)
        try c.encode(format, forKey: RecordKey("format"))
        try c.encode(version, forKey: RecordKey("version"))
        try c.encode(savedAt, forKey: RecordKey("savedAt"))
        try c.encode(title, forKey: RecordKey("title"))
        try c.encode(score, forKey: RecordKey("score"))
        try c.encode(concept, forKey: RecordKey("concept"))
        try c.encodeIfPresent(provider, forKey: RecordKey("provider"))
        try c.encodeIfPresent(model, forKey: RecordKey("model"))
        try c.encode(measures, forKey: RecordKey("measures"))
        try c.encode(meter, forKey: RecordKey("meter"))
        try c.encode(tempo, forKey: RecordKey("tempo"))
        try c.encode(musicalKey, forKey: RecordKey("musicalKey"))
        try c.encode(ensemble, forKey: RecordKey("ensemble"))
        try c.encode(assignment, forKey: RecordKey("assignment"))
        try c.encodeIfPresent(sourceName, forKey: RecordKey("sourceName"))
        try c.encodeIfPresent(sourceScore, forKey: RecordKey("sourceScore"))
        try c.encodeIfPresent(midiData, forKey: RecordKey("midiData"))
        try c.encodeIfPresent(musicXMLData, forKey: RecordKey("musicXMLData"))
        try c.encodeIfPresent(originalMusicXMLData, forKey: RecordKey("originalMusicXMLData"))
        try c.encodeIfPresent(costUSD, forKey: RecordKey("costUSD"))
        try c.encodeIfPresent(inputTokens, forKey: RecordKey("inputTokens"))
        try c.encodeIfPresent(outputTokens, forKey: RecordKey("outputTokens"))
        for (name, value) in extraFields where !Self.recordFields.contains(name) { try c.encode(value, forKey: RecordKey(name)) }
    }
}

extension CompositionWorkspace {
    private static let recordFields: Set<String> = ["format", "name", "activeSlot", "slots", "settings", "history", "concept", "chat"]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RecordKey.self)
        format = try c.decode(String.self, forKey: RecordKey("format"))
        name = try c.decode(String.self, forKey: RecordKey("name"))
        activeSlot = try c.decode(Int.self, forKey: RecordKey("activeSlot"))
        slots = try c.decode([HistoryItem?].self, forKey: RecordKey("slots"))
        settings = try c.decode(AppSettings.self, forKey: RecordKey("settings"))
        history = try c.decode([HistoryItem].self, forKey: RecordKey("history"))
        concept = try c.decodeIfPresent(String.self, forKey: RecordKey("concept"))
        chat = try c.decodeIfPresent(String.self, forKey: RecordKey("chat"))
        extraFields = [:]
        for key in c.allKeys where !Self.recordFields.contains(key.stringValue) { extraFields[key.stringValue] = try c.decode(JSONValue.self, forKey: key) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: RecordKey.self)
        try c.encode(format, forKey: RecordKey("format"))
        try c.encode(name, forKey: RecordKey("name"))
        try c.encode(activeSlot, forKey: RecordKey("activeSlot"))
        try c.encode(slots, forKey: RecordKey("slots"))
        try c.encode(settings, forKey: RecordKey("settings"))
        try c.encode(history, forKey: RecordKey("history"))
        try c.encodeIfPresent(concept, forKey: RecordKey("concept"))
        try c.encodeIfPresent(chat, forKey: RecordKey("chat"))
        for (name, value) in extraFields where !Self.recordFields.contains(name) { try c.encode(value, forKey: RecordKey(name)) }
    }
}
