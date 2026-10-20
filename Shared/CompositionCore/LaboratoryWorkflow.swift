import Foundation

/// Shared laboratory policy. A laboratory result is isolated until explicitly
/// transferred; analysis must not create or replace a composition.
public enum LaboratoryWorkflow {
    public static func prompt(kind: String, task: String, first: String = "", second: String = "",
                              measures: Int = 4, tempo: String = "", ensemble: String = "", style: String = "") throws -> String {
        let material = "MUSIK A:\n" + first + "\n\nMUSIK B:\n" + second + "\n\nNUTZER:\n" + task
        switch kind {
        case "motif":
            guard (1...16).contains(measures) else { throw APIError.badResponse("Ein Motiv muss zwischen 1 und 16 Takten lang sein.") }
            return """
            \(ComposerPrompts.technical)
            AUFGABE: Erzeuge nur ein prägnantes musikalisches Motiv / eine Keimzelle, kein vollständiges Stück.
            Exakte Länge: \(measures) Takte. Taktart: 4/4.
            \(tempo.isEmpty ? "" : "Tempo: " + tempo)
            \(ensemble.isEmpty ? "" : "Besetzung: " + ensemble)
            \(style.isEmpty ? "" : "Stil / Charakter: " + style)
            Auftrag: \(task)
            Keine Einleitung, Durchführung, Reprise oder Coda ergänzen.
            Die JSON-Partitur endet spätestens am Ende von Takt \(measures).
            Gib ausschließlich die JSON-Partitur aus. Das Material bleibt im Labor isoliert.
            """
        case "compare":
            return "Vergleiche A und B musikalisch. Beurteile Charakter, motivische Arbeit, Harmonik, Rhythmik, Form und Eigenständigkeit konkret. Keine neue Partitur.\n" + material
        case "analysis":
            return "Besprich die vorliegenden Kompositionen konkret und musikalisch. Antworte als Gesprächspartner; verändere keine Noten und erzeuge keine neue Partitur.\n" + material
        case "revision":
            return "Erzeuge die ausdrücklich gewünschte neue Fassung aus dem angegebenen Ausgangsmaterial. Gib die vollständige fertige Komposition aus.\n" + material + "\n" + ComposerPrompts.technical
        case "route":
            return "Wenn der Nutzer eine neue oder veränderte musikalische Fassung verlangt, antworte ausschließlich [[COMPOSE]]. Bei Fragen oder Analyse antworte als musikalischer Gesprächspartner. Erzeuge in diesem Routingaufruf keine Musik, kein Skript und keine Binärdaten.\n" + material
        default: throw APIError.badResponse("Unbekannte Laboroperation.")
        }
    }
    public static func validateMotif(scoreJSON: Data, measures: Int) throws {
        guard (1...16).contains(measures) else { throw APIError.badResponse("Ungültige Motivlänge.") }
        let score = try ScoreDecoder.decode(scoreJSON)
        try ScoreValidation.validate(score)
        let limit = Double(measures * score.ts.n) * 4 / Double(score.ts.d) + 0.0001
        guard score.tr.allSatisfy({ $0.nt.allSatisfy { $0[0] + $0[1] <= limit } }) else {
            throw APIError.badResponse("Motiv verworfen: Die KI lieferte mehr als die angeforderten Takte.")
        }
    }
}
