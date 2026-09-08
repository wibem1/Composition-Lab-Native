import Cocoa
import Foundation
import CryptoKit
import Security

@MainActor
final class SessionSecrets {
    static let shared = SessionSecrets()
    private var keys: [Provider:String] = [:]
    private(set) var backupPassword: String?

    private init() {
        keys = LocalSecretsStore.load()
    }

    func key(for provider: Provider) -> String { keys[provider] ?? "" }
    func set(_ value: String, for provider: Provider) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty { keys.removeValue(forKey: provider) } else { keys[provider] = v }
        LocalSecretsStore.save(keys)
    }
    func remove(_ provider: Provider) {
        keys.removeValue(forKey: provider)
        LocalSecretsStore.save(keys)
    }
    func exportKeys() -> [String:String] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0.key.rawValue, $0.value) })
    }
    func importKeys(_ raw: [String:String]) {
        keys.removeAll()
        for (k,v) in raw { if let p = Provider(rawValue:k), !v.isEmpty { keys[p] = v } }
        LocalSecretsStore.save(keys)
    }
    func rememberBackupPassword(_ value: String?) { backupPassword = value }
}

private struct LocalSecretsEnvelope: Codable {
    var format = "composition-lab-native-local-secrets"
    var version = 1
    var combined: String
}

private enum LocalSecretsStore {
    private static let keyDefaultsName = "CompositionLab.LocalSecretsKey.v1"

    private static var directoryURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Composition Lab", isDirectory: true)
    }
    private static var fileURL: URL? { directoryURL?.appendingPathComponent("api-secrets.dat") }

    private static func localKey() -> SymmetricKey {
        let defaults = UserDefaults.standard
        if let encoded = defaults.string(forKey: keyDefaultsName), let data = Data(base64Encoded: encoded), data.count == 32 {
            return SymmetricKey(data: data)
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let data = Data(bytes)
        defaults.set(data.base64EncodedString(), forKey: keyDefaultsName)
        return SymmetricKey(data: data)
    }

    static func load() -> [Provider:String] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let env = try? JSONDecoder().decode(LocalSecretsEnvelope.self, from: data),
              env.format == "composition-lab-native-local-secrets",
              let combined = Data(base64Encoded: env.combined),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plain = try? AES.GCM.open(box, using: localKey()),
              let raw = try? JSONDecoder().decode([String:String].self, from: plain)
        else { return [:] }
        var result: [Provider:String] = [:]
        for (k,v) in raw { if let p = Provider(rawValue:k), !v.isEmpty { result[p] = v } }
        return result
    }

    static func save(_ keys: [Provider:String]) {
        guard let dir = directoryURL, let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let raw = Dictionary(uniqueKeysWithValues: keys.map { ($0.key.rawValue, $0.value) })
            let plain = try JSONEncoder().encode(raw)
            let sealed = try AES.GCM.seal(plain, using: localKey())
            guard let combined = sealed.combined else { return }
            let env = LocalSecretsEnvelope(combined: combined.base64EncodedString())
            let data = try JSONEncoder().encode(env)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            NSLog("Composition Lab: API-Schlüssel konnten nicht lokal gespeichert werden: %@", error.localizedDescription)
        }
    }
}


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
}

struct CompositionLabBackupPayload: Codable {
    var format = "composition-lab-native-backup-payload"
    var version = 1
    var savedAt = Date()
    var settings: AppSettings
    var history: [HistoryItem]
    var apiKeys: [String:String]
}

private struct CompositionLabBackupEnvelope: Codable {
    var format = "composition-lab-native-backup"
    var version = 1
    var salt: String
    var combined: String
}

enum BackupCryptoError: LocalizedError {
    case invalidFile, badPassword
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "Die Backup-Datei ist ungültig."
        case .badPassword: return "Das Backup-Passwort ist falsch oder die Datei ist beschädigt."
        }
    }
}

enum BackupCrypto {
    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    // Lokale Passwortableitung. Der Schlüssel wird nie gespeichert.
    private static func key(password: String, salt: Data) -> SymmetricKey {
        var material = Data(password.utf8) + salt
        for _ in 0..<50_000 { material = Data(SHA256.hash(data: material)) }
        return SymmetricKey(data: material)
    }

    static func encrypt(_ payload: CompositionLabBackupPayload, password: String) throws -> Data {
        let plain = try JSONEncoder.pretty.encode(payload)
        let salt = randomBytes(16)
        let sealed = try AES.GCM.seal(plain, using: key(password:password, salt:salt))
        guard let combined = sealed.combined else { throw BackupCryptoError.invalidFile }
        let env = CompositionLabBackupEnvelope(salt:salt.base64EncodedString(), combined:combined.base64EncodedString())
        return try JSONEncoder.pretty.encode(env)
    }

    static func decrypt(_ data: Data, password: String) throws -> CompositionLabBackupPayload {
        guard let env = try? JSONDecoder().decode(CompositionLabBackupEnvelope.self, from:data),
              env.format == "composition-lab-native-backup",
              let salt = Data(base64Encoded:env.salt),
              let combined = Data(base64Encoded:env.combined),
              let box = try? AES.GCM.SealedBox(combined:combined)
        else { throw BackupCryptoError.invalidFile }
        do {
            let plain = try AES.GCM.open(box, using:key(password:password, salt:salt))
            return try JSONDecoder().decode(CompositionLabBackupPayload.self, from:plain)
        } catch { throw BackupCryptoError.badPassword }
    }
}

@MainActor
func askText(title:String, message:String, defaultValue:String="", secure:Bool=false) -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle:"OK")
    alert.addButton(withTitle:"Abbrechen")
    let field: NSTextField = secure ? NSSecureTextField(string:defaultValue) : NSTextField(string:defaultValue)
    field.frame = NSRect(x:0,y:0,width:320,height:24)
    alert.accessoryView = field
    alert.window.initialFirstResponder = field
    return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
}
