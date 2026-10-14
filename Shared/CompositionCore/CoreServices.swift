import Foundation

/// Small public boundary for desktop clients. JSON preserves the existing score
/// and CLAB wire format; AppKit and Windows APIs never enter this module.
public enum CoreServices {
    public static let version = "4.0.0-alpha.8"

    public static func midi(scoreJSON: Data) throws -> Data {
        MIDIBuilder.build(try validatedScore(scoreJSON))
    }

    public static func musicXML(scoreJSON: Data, optionsJSON: Data? = nil) throws -> Data {
        let options = try optionsJSON.map { try JSONDecoder().decode(MusicXMLDisplayOptions.self, from: $0) } ?? .readablePiano
        guard let data = MusicXMLBuilder.build(try validatedScore(scoreJSON), options: options) else {
            throw APIError.badResponse("MusicXML konnte nicht erzeugt werden.")
        }
        return data
    }

    public static func importMIDI(_ data: Data, title: String) throws -> Data {
        try encodeValidated(MIDIParser.parse(data: data, fallbackTitle: title))
    }

    public static func importMusicXML(_ data: Data, title: String) throws -> Data {
        try encodeValidated(MusicXMLParser.parse(data: data, fallbackTitle: title))
    }

    /// Validate a complete existing CLAB document without dropping optional fields.
    public static func validateDocument(_ data: Data) throws {
        let document = try JSONDecoder().decode(CompositionLabDocument.self, from: data)
        guard document.format == "composition-lab-document", document.version == 1 else {
            throw APIError.badResponse("Unbekanntes CLAB-Format.")
        }
        try ScoreValidation.validate(document.score)
    }

    public static func validateWorkspace(_ data: Data) throws {
        struct Workspace: Decodable { let format: String; let name: String; let activeSlot: Int; let slots: [HistoryItem?]; let settings: AppSettings; let history: [HistoryItem] }
        let workspace = try JSONDecoder().decode(Workspace.self, from: data)
        guard workspace.format == "composition-lab-v6-project", (0..<10).contains(workspace.activeSlot), workspace.slots.count <= 10 else { throw APIError.badResponse("Ungültiger Arbeitsplatz.") }
        for item in workspace.slots.compactMap({ $0 }) + workspace.history { try ScoreValidation.validate(item.score) }
    }

    public static func compositionPrompt(assignment: String) -> String {
        ComposerPrompts.compositionPrompt(assignment)
    }

    public static func translationPrompt(composition: String) -> String {
        ComposerPrompts.translationPrompt(composition: composition)
    }

    public static func recoverScore(response: String) throws -> Data {
        try encodeValidated(ScoreDecoder.decode(APIClient.shared.extractJSON(response)))
    }

    /// requestJSON: assignment, provider (openai/anthropic/gemini), model, effort
    /// (low/medium/high). API key is supplied separately and never serialized.
    public static func compose(requestJSON: Data, apiKey: String,
                               progress: ((String) -> Void)? = nil,
                               completion: @escaping (Result<Data, Error>) -> Void) {
        do {
            let dto = try JSONDecoder().decode(RequestDTO.self, from: requestJSON)
            guard !dto.assignment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !dto.model.isEmpty, !apiKey.isEmpty else {
                throw APIError.badResponse("Auftrag, Modell und API-Schlüssel fehlen.")
            }
            let request = CompositionRequest(assignment: dto.assignment, provider: dto.provider,
                model: dto.model, effort: dto.effort, key: apiKey)
            CompositionWorkflow().compose(request, progress: { stage, _ in
                progress?(stage.rawValue)
            }) { result in
                switch result {
                case .success(let work):
                    completion(Result { try JSONSerialization.data(withJSONObject: work.diagnostic,
                                                                   options: [.prettyPrinted, .sortedKeys]) })
                case .failure(let failure):
                    let data = (try? JSONSerialization.data(withJSONObject: failure.diagnostic,
                                                            options: [.prettyPrinted, .sortedKeys])) ?? Data()
                    completion(.failure(CoreCompositionError(message: failure.localizedDescription,
                                                             diagnosticJSON: data)))
                }
            }
        } catch { completion(.failure(error)) }
    }

    public static func chat(requestJSON: Data, apiKey: String,
                            completion: @escaping (Result<Data, Error>) -> Void) {
        do {
            let dto = try JSONDecoder().decode(RequestDTO.self, from: requestJSON)
            guard !dto.assignment.isEmpty, !apiKey.isEmpty else { throw APIError.emptyResponse }
            APIClient.shared.call(provider: dto.provider, model: dto.model, key: apiKey,
                effort: dto.effort, purpose: "music-chat", system: "", user: dto.assignment,
                wantJSON: false) { result in
                completion(result.flatMap { response in Result {
                    let diagnostic: [String: Any] = ["text": response.text,
                        "inputTokens": response.inputTokens, "outputTokens": response.outputTokens,
                        "estimatedCostUSD": APICost.estimate(provider: dto.provider, model: dto.model,
                            inputTokens: response.inputTokens, outputTokens: response.outputTokens)]
                    return try JSONSerialization.data(withJSONObject: diagnostic)
                } })
            }
        } catch { completion(.failure(error)) }
    }

    private struct RequestDTO: Decodable {
        let assignment: String
        let provider: Provider
        let model: String
        let effort: Effort
    }

    private static func validatedScore(_ data: Data) throws -> Score {
        let score = try ScoreDecoder.decode(data)
        try ScoreValidation.validate(score)
        return score
    }

    private static func encodeValidated(_ score: Score) throws -> Data {
        try ScoreValidation.validate(score)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(score)
    }
}

public struct CoreCompositionError: Error, LocalizedError {
    public let message: String
    public let diagnosticJSON: Data
    public var errorDescription: String? { message }
}
