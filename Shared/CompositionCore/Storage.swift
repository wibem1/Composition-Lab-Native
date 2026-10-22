import Foundation

/// A test domain isolates automated native UI checks from the user's settings.
/// Production keeps its existing preference domains and migration paths.
enum AppPreferences {
    static let standard: UserDefaults = {
        if let domain = ProcessInfo.processInfo.environment["COMPOSITION_LAB_TEST_DOMAIN"], !domain.isEmpty,
           let defaults = UserDefaults(suiteName: domain) { return defaults }
        return UserDefaults.standard
    }()
}

struct CurrentPlayerState: Codable {
    var score: Score
    var concept: String
    var provider: Provider
    var model: String
    var costUSD: Double
    var inputTokens: Int
    var outputTokens: Int
    var importedReferenceScore: Score?
    var importedReferenceName: String?
    var importedReferenceMusicXMLData: Data?
}


final class Storage {
    static let shared = Storage()
    private let defaults: UserDefaults = {
        if ProcessInfo.processInfo.environment["COMPOSITION_LAB_TEST_DOMAIN"] != nil { return AppPreferences.standard }
        let identifier = "de.klangwerke.compositionlab.native.v4"
        // A bundle must use its standard domain, not open itself as a suite.
        if Bundle.main.bundleIdentifier == identifier { return .standard }
        return UserDefaults(suiteName: identifier) ?? .standard
    }()

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: "settings"),
              let value = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return value
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: "settings")
        }
    }

    func loadNotationProfile() -> NotationProfile? {
        guard let data = defaults.data(forKey: "notationProfile"),
              let value = try? JSONDecoder().decode(NotationProfile.self, from: data)
        else { return nil }
        return value
    }

    func saveNotationProfile(_ profile: NotationProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: "notationProfile")
        }
    }

    func loadCurrentPlayerState() -> CurrentPlayerState? {
        guard let data = defaults.data(forKey: "currentPlayerState"),
              let value = try? JSONDecoder().decode(CurrentPlayerState.self, from: data)
        else { return nil }
        return value
    }

    func saveCurrentPlayerState(_ state: CurrentPlayerState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: "currentPlayerState")
        }
    }

    func clearCurrentPlayerState() {
        defaults.removeObject(forKey: "currentPlayerState")
    }

    func loadHistory() -> [HistoryItem] {
        guard let data = defaults.data(forKey: "history"),
              let value = try? JSONDecoder().decode([HistoryItem].self, from: data)
        else { return [] }
        return value
    }

    func saveHistory(_ history: [HistoryItem]) {
        let trimmed = Array(history.prefix(15))
        if let data = try? JSONEncoder().encode(trimmed) {
            defaults.set(data, forKey: "history")
        }
    }
}
