import Foundation

/// Shared dialogue contract. Planning never overwrites a score or triggers
/// composition; source slots must be chosen explicitly by the user request.
public enum WorkspaceDialogue {
    public static func prompt(message: String, workspace: String) -> String {
        return """
        Du bist der musikalische Gesprächspartner im MusicChat von Composition Lab.
        Dieser Aufruf dient ausschließlich Gespräch und Ideenarbeit; er erzeugt keine Partitur.

        Der ARBEITSRAUM ist Gedächtnis und Orientierung, nicht automatisch musikalisches Ausgangsmaterial.
        Vorhandene Slots oder eine frühere Kompositionsidee werden nur dann zu Material, wenn der aktuelle
        Nutzerwunsch erkennbar darauf Bezug nimmt. sourceSlots nennt ausschließlich solche tatsächlich
        gewünschten Quellen. Bei einem neuen Kompositionsvorhaben entwickelst du die Idee aus dem aktuellen
        Nutzerwunsch und den ausdrücklich gesetzten Rahmenbedingungen.

        Antworte ausschließlich als JSON:
        {
          "reply":"natürliche Dialogantwort",
          "compositionAssignment": null ODER "aktueller Kompositionsauftrag",
          "compositionIdea": null ODER "aktuelle musikalische Vorstellung",
          "sourceSlots":[1,2],
          "resolvedSettings":{"measures":"4","meter":"4/4","tempo":null,"key":"d-Moll","ensemble":"Klavier"}
        }
        Gib resolvedSettings nur für im aktuellen Nutzerwunsch ausdrücklich genannte Werte zurück; sonst null.
        Ein neuer Kompositionsauftrag darf alte Einstellungen nicht stillschweigend übernehmen, wenn sie ihm widersprechen.

        ARBEITSRAUM:
        \(workspace)

        AKTUELLER NUTZERBEITRAG:
        \(message)
        """
    }
    public static func decode(_ text: String) throws -> Data {
        let raw = try APIClient.shared.extractJSON(text)
        guard var object = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let reply = object["reply"] as? String, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.badResponse("MusicChat hat keine gültige Dialogantwort geliefert.")
        }
        let sources = object["sourceSlots"] as? [Int] ?? []
        guard sources.allSatisfy({ (1...10).contains($0) }) else { throw APIError.badResponse("MusicChat nennt einen ungültigen Quell-Slot.") }
        object["sourceSlots"] = Array(Set(sources)).sorted()
        let settings = object["resolvedSettings"] as? [String: Any] ?? [:]
        object["resolvedSettings"] = settings.filter { ["measures", "meter", "tempo", "key", "ensemble"].contains($0.key) && ($0.value is String || $0.value is NSNumber) }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
