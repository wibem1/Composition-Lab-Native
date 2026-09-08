import Foundation
import Security

enum KeychainStore {
    private static let service = "AI MIDI Composer Native Concept"
    private static var cache: [Provider:String] = [:]
    private static var attemptedLoads = Set<Provider>()

    /// Liefert nur einen bereits in dieser App-Sitzung geladenen Schlüssel.
    /// Dabei wird der macOS-Schlüsselbund NICHT angesprochen.
    static func cached(provider: Provider) -> String? {
        return cache[provider]
    }

    static func save(_ value: String, provider: Provider) throws {
        let account = provider.rawValue
        let data = Data(value.utf8)
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        cache[provider] = value
        attemptedLoads.insert(provider)
    }

    /// Greift nur dann wirklich auf den Schlüsselbund zu, wenn für diesen Anbieter
    /// in der laufenden App-Sitzung noch kein Schlüssel im Speicher liegt.
    static func load(provider: Provider) -> String {
        if let value = cache[provider] { return value }
        // Pro Anbieter höchstens ein automatischer Schlüsselbund-Zugriff je App-Sitzung.
        // Das verhindert wiederholte macOS-Passwortdialoge, wenn der Zugriff abgelehnt
        // oder durch eine neue ad-hoc-Signatur erneut bestätigt werden müsste.
        if attemptedLoads.contains(provider) { return "" }
        attemptedLoads.insert(provider)
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return "" }
        let value = String(data: data, encoding: .utf8) ?? ""
        if !value.isEmpty { cache[provider] = value }
        return value
    }

    static func delete(provider: Provider) {
        cache.removeValue(forKey: provider)
        attemptedLoads.remove(provider)
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
