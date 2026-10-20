import Foundation

/// Musical register checks and the acceptance contract for an explicitly
/// requested octave repair. Scanning never changes notes or calls a provider.
public enum RegisterReview {
    public static let instruction = "Korrigiere ausschließlich unbeabsichtigte Oktavlagen im folgenden vollständigen LilyPond-Stück. Keine neue Komposition. Erhalte alle Noten, Tonklassen, Rhythmen, Taktarten, Tempi, Stimmenreihenfolge, Instrumente, Artikulation und Dynamik exakt. Wähle zusammenhängende musikalische Phrasen statt einzelne Noten blind in einen Zielbereich zu falten. Keine Korrektur durch ottava. Gib ausschließlich vollständigen LilyPond-Code mit absoluten Tonhöhen ohne \\relative aus. Klavierumfang MIDI 21–108."

    public static func inspect(scoreJSON: Data) throws -> Data {
        let score = try ScoreDecoder.decode(scoreJSON)
        try ScoreValidation.validate(score)
        var issues: [[String: Any]] = []
        for (index, track) in score.tr.enumerated() {
            let piano = (0...7).contains(track.pg), strings = (40...51).contains(track.pg)
            guard piano || strings, !track.nt.isEmpty else { continue }
            let outside = track.nt.filter { $0[2] < (piano ? 21 : 36) || $0[2] > (piano ? 108 : 100) }
            let high = track.nt.filter { $0[2] >= 96 }
            guard !outside.isEmpty || high.count >= 3 else { continue }
            issues.append(["track": index + 1, "instrument": track.nm,
                "minimum": track.nt.map { $0[2] }.min()!, "maximum": track.nt.map { $0[2] }.max()!,
                "outsideKeyboard": outside.count,
                "reason": outside.isEmpty ? "Anhaltend extreme hohe Lage (Verdacht auf Oktavfehler)" : (piano ? "Töne außerhalb A0–C8" : "Auffällige Streicherlage außerhalb C2–E7"),
                "beats": Array((outside.isEmpty ? high : outside).prefix(12)).map { $0[0] }])
        }
        return try JSONSerialization.data(withJSONObject: issues, options: [.sortedKeys])
    }

    /// Compare the complete musical score, including channel events and
    /// expression. Only octave displacement and descriptive text may differ.
    public static func octaveOnly(before: Data, after: Data) throws -> Bool {
        func signature(_ data: Data) throws -> Data {
            let score = try ScoreDecoder.decode(data)
            try ScoreValidation.validate(score)
            var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(score)) as! [String: Any]
            object.removeValue(forKey: "ti"); object.removeValue(forKey: "sm")
            var tracks = object["tr"] as! [[String: Any]]
            for i in tracks.indices {
                let notes = tracks[i]["nt"] as! [[Double]]
                tracks[i]["nt"] = try notes.map { note -> String in
                    var n = note
                    n[2] = n[2].truncatingRemainder(dividingBy: 12)
                    n = n.map { ($0 * 1_000_000).rounded() / 1_000_000 }
                    return String(decoding: try JSONEncoder().encode(n), as: UTF8.self)
                }.sorted()
            }
            object["tr"] = tracks
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        return try signature(before) == signature(after)
    }

    public static func validateRepair(before: Data, after: Data, source: String) throws {
        let a = try ScoreDecoder.decode(before), b = try ScoreDecoder.decode(after)
        guard a.tr.map({ $0.nt }) != b.tr.map({ $0.nt }) else { throw APIError.badResponse("Keine klingende Tonhöhe verändert. Keine Oktavkorrektur übernommen.") }
        guard try octaveOnly(before: before, after: after) else { throw APIError.badResponse("Oktavkorrektur verändert weitere musikalische Eigenschaften und wurde verworfen.") }
        let masked = try LilyPondSource.maskedNotation(source)
        let remaining = try JSONSerialization.jsonObject(with: inspect(scoreJSON: after)) as! [[String: Any]]
        guard !masked.contains("\\relative"), remaining.isEmpty else {
            throw APIError.badResponse("Die Oktavkorrektur ist weiterhin auffällig und wurde nicht übernommen.")
        }
    }
}
