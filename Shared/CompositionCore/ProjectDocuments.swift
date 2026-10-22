import Foundation

struct CompositionLabProject: Codable {
    var format = "composition-lab-native-project"
    var version = 1
    var name: String
    var savedAt = Date()
    var settings: AppSettings
    var concept: String
    var score: Score?
    var source: Score?
    var sourceName: String?
    var history: [HistoryItem]
    var experimentConcept: String
    var experimentScore: Score?
}


struct CompositionLabDocument: Codable {
    var format = "composition-lab-document"
    var version = 1
    var savedAt = Date()
    var title: String
    var score: Score
    var concept: String
    var provider: Provider?
    var model: String?
    var measures: String
    var meter: String
    var tempo: String
    var musicalKey: String
    var ensemble: String
    var assignment: String
    var sourceName: String?
    var sourceScore: Score?

    /// Legacy-Felder aus CLAB V4.7.1–V4.7.3.
    /// Sie bleiben zum Lesen alter Dateien erhalten, werden aber nicht mehr neu befüllt.
    /// Exportdarstellungen werden immer frisch aus `score` erzeugt.
    var midiData: Data?
    var musicXMLData: Data?

    /// Bei Import einer MusicXML-Datei zusätzlich das unveränderte Original.
    var originalMusicXMLData: Data?

    var costUSD: Double?
    var inputTokens: Int?
    var outputTokens: Int?
    var extraFields: [String: JSONValue] = [:]

}

struct CompositionLabBackupPayload: Codable {
    var format = "composition-lab-native-backup-payload"
    var version = 1
    var savedAt = Date()
    var settings: AppSettings
    var history: [HistoryItem]
    var apiKeys: [String:String]
}


struct CompositionWorkspace: Codable {
    var format = "composition-lab-v6-project"
    var name: String
    var activeSlot: Int
    var slots: [HistoryItem?]
    var settings: AppSettings
    var history: [HistoryItem]
    var concept: String? = nil
    var chat: String? = nil
    var extraFields: [String: JSONValue] = [:]
}
