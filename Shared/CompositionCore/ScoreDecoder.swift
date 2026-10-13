import Foundation

/// Accepts explicit aliases used by technical translators, without changing notes.
/// Raw provider responses remain in the diagnostic; invalid/ambiguous structures
/// fail with a concrete JSON path instead of silently dropping expression data.
enum ScoreDecoder {
    static func decode(_ data: Data) throws -> Score {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var tracks = object["tr"] as? [[String: Any]] else {
            throw APIError.badResponse("Partitur: tr muss eine Liste von Stimmen sein.")
        }
        for index in tracks.indices {
            let notes = tracks[index]["nt"] as? [[Double]] ?? []
            if let events = tracks[index]["ev"] as? [[String: Any]] {
                var canonical: [[String: Any]] = []
                for (eventIndex, raw) in events.enumerated() {
                    let path = "tr[\(index)].ev[\(eventIndex)]"
                    guard let type = raw["t"] as? String else {
                        throw APIError.badResponse("\(path): Ereignistyp t fehlt.")
                    }
                    var event = raw
                    if event["st"] == nil { event["st"] = raw["staff"] }
                    if event["v"] == nil { event["v"] = raw["text"] }
                    if event["n"] == nil { event["n"] = raw["qpm"] }
                    if event["e"] == nil { event["e"] = raw["to"] }
                    switch type.lowercased() {
                    case "dynamic": event["t"] = "dyn"
                    case "crescendo", "decrescendo", "diminuendo":
                        event["t"] = "wedge"; event["v"] = type.lowercased() == "diminuendo" ? "decrescendo" : type.lowercased()
                    case "accent", "marcato", "staccato", "tenuto", "fermata":
                        event["t"] = "art"; event["v"] = type.lowercased()
                    default: break
                    }
                    func matching(_ note: [Double]) -> Bool {
                        guard note.count >= 4, note.allSatisfy({ $0.isFinite }) else { return false }
                        if let staff = (event["st"] as? NSNumber)?.intValue,
                           note.count >= 5, note[4] != Double(staff) { return false }
                        if let pitch = (event["p"] as? NSNumber)?.intValue, note[2] != Double(pitch) { return false }
                        return true
                    }
                    if let ranges = raw["ranges"] as? [[Double]] {
                        guard type == "slur" || type == "tie", !ranges.isEmpty else {
                            throw APIError.badResponse("\(path): Unbekanntes Bereichsformat für \(type).")
                        }
                        for range in ranges {
                            guard range.count == 2, range.allSatisfy({ $0.isFinite }), range[1] > range[0] else {
                                throw APIError.badResponse("\(path): Ungültiger Bereich.")
                            }
                            var ranged = event; ranged.removeValue(forKey: "ranges")
                            ranged["b"] = range[0]
                            if type == "slur" {
                                // Legacy ranges describe [start, exclusive end].
                                let end = notes.filter { matching($0) && $0[0] >= range[0] && $0[0] < range[1] }
                                    .map { $0[0] }.max()
                                guard let end, end > range[0] else {
                                    throw APIError.badResponse("\(path): Phrasierungsbogen enthält keine zwei Einsätze.")
                                }
                                ranged["e"] = end
                            } else {
                                // A translator may have already merged tied durations.
                                let merged = notes.contains { matching($0) && abs($0[0] - range[0]) < 0.0001 && $0[0] + $0[1] >= range[1] - 0.0001 }
                                let hasContinuation = notes.contains { matching($0) && abs($0[0] - range[1]) < 0.0001 }
                                if merged && !hasContinuation { continue }
                                ranged["e"] = range[1]
                            }
                            canonical.append(ranged)
                        }
                    } else {
                        guard let beat = event["b"] as? NSNumber else {
                            throw APIError.badResponse("\(path): Startbeat b fehlt.")
                        }
                        if type == "fermata", !notes.contains(where: { matching($0) && abs($0[0] - beat.doubleValue) < 0.0001 }),
                           let last = notes.filter({ matching($0) && $0[0] < beat.doubleValue && $0[0] + $0[1] >= beat.doubleValue - 0.0001 }).map({ $0[0] }).max() {
                            event["b"] = last
                        }
                        canonical.append(event)
                    }
                }
                tracks[index]["ev"] = canonical
            }
        }
        object["tr"] = tracks
        do { return try JSONDecoder().decode(Score.self, from: JSONSerialization.data(withJSONObject: object)) }
        catch let error as DecodingError {
            let context: DecodingError.Context
            var missing = ""
            switch error {
            case .keyNotFound(let key, let c): context = c; missing = "." + key.stringValue
            case .typeMismatch(_, let c), .valueNotFound(_, let c), .dataCorrupted(let c): context = c
            @unknown default: throw error
            }
            throw APIError.badResponse("Partiturformat bei " + context.codingPath.map { $0.stringValue }.joined(separator: ".") + missing + ": " + context.debugDescription)
        }
    }
}
