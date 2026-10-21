import Foundation

/// Owns one request's transport, so cancellation cannot stop another laboratory.
public final class CoreRequestHandle {
    private let client: APIClient
    init(client: APIClient) { self.client = client }
    public func cancel() { client.cancel() }
}

/// Small public boundary for desktop clients. JSON preserves the existing score
/// and CLAB wire format; AppKit and Windows APIs never enter this module.
public enum CoreServices {
    public static let version = "4.2.9"

    /// Stateless catalog boundary. State contains model metadata and cursors,
    /// never keys; adapters supply a provider response only after HTTP success.
    public static func modelCatalogStep(provider: String, stateJSON: Data? = nil, pageJSON: Data? = nil) throws -> Data {
        guard let provider = Provider(rawValue: provider) else { throw APIError.badResponse("Unbekannter Provider.") }
        var state = try stateJSON.map { try JSONDecoder().decode(ModelCatalogState.self, from: $0) }
            ?? ModelCatalogState(provider: provider)
        guard state.provider == provider else { throw APIError.badResponse("Provider der Modellseite stimmt nicht überein.") }
        if let pageJSON { try state.consume(pageJSON) }
        var response: [String: Any] = ["state": try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))]
        if !state.complete { response["request"] = state.request }
        return try JSONSerialization.data(withJSONObject: response)
    }

    /// Interpret a finished answer locally. Never calls a provider, repairs
    /// music or falls back to a paid technical translation.
    public static func initialMIDITempo(_ data: Data) throws -> Double { try PlaybackMIDICopy.initialBPM(data) }

    public static func playbackMIDICopy(_ original: Data, velocityFactor: Double, targetBPM: Double? = nil) throws -> Data {
        try PlaybackMIDICopy.make(original, velocityFactor: velocityFactor, targetBPM: targetBPM)
    }

    public static func interpretComposition(_ original: String) throws -> Data {
        if let source = try? LilyPondSource.extract(original), source.contains("\\score") {
            return try JSONSerialization.data(withJSONObject: ["kind": "lilypond", "source": source])
        }
        var text = original.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```"), let first = text.firstIndex(of: "\n"), let last = text.range(of: "```", options: .backwards), last.lowerBound > first {
            text = String(text[text.index(after: first)..<last.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let score: Score?
        if text.hasPrefix("{") { score = try? ScoreDecoder.decode(Data(text.utf8)) }
        else if text.hasPrefix("<?xml") || text.hasPrefix("<score-partwise") {
            score = try? MusicXMLParser.parse(data: Data(text.utf8), fallbackTitle: "Komposition")
        } else { score = nil }
        guard let score else { return try JSONSerialization.data(withJSONObject: ["kind": "unrecognized"]) }
        try ScoreValidation.validate(score)
        return try JSONSerialization.data(withJSONObject: ["kind": "score", "score": try JSONSerialization.jsonObject(with: JSONEncoder().encode(score))])
    }

    public static func sourceSelection(rendered: String, editor: String, fromLine: Int, fromCharacter: Int, toLine: Int, toCharacter: Int) throws -> Data {
        try JSONEncoder().encode(LilyPondSource.selection(rendered: rendered, editor: editor,
            from: .init(line: fromLine, character: fromCharacter), to: .init(line: toLine, character: toCharacter)))
    }

    public static func prepareLilyPond(_ source: String) throws -> String { try LilyPondSource.prepare(source) }
    public static func extractLilyPond(_ source: String) throws -> String { try LilyPondSource.extract(source) }

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

    public static func validateBackup(_ data: Data) throws {
        let payload = try JSONDecoder().decode(CompositionLabBackupPayload.self, from: data)
        guard payload.format == "composition-lab-native-backup-payload", payload.version == 1,
              payload.apiKeys.keys.allSatisfy({ Provider(rawValue: $0) != nil }) else { throw APIError.badResponse("Ungültiges Backupformat.") }
        for item in payload.history { try ScoreValidation.validate(item.score) }
    }

    public static func validateWorkspace(_ data: Data) throws {
        let workspace = try JSONDecoder().decode(CompositionWorkspace.self, from: data)
        guard workspace.format == "composition-lab-v6-project", (0..<10).contains(workspace.activeSlot), workspace.slots.count <= 10 else { throw APIError.badResponse("Ungültiger Arbeitsplatz.") }
        for item in workspace.slots.compactMap({ $0 }) + workspace.history { try ScoreValidation.validate(item.score) }
    }

    /// Include only musical parameters the user actually supplied. Empty UI
    /// fields must not silently impose a 32-bar, 4/4, 96-BPM composition.
    public static func visibleAssignment(chat: String, idea: String, fallback: String) -> String {
        [chat, idea, fallback].first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
    }

    public struct CompositionInput {
        public let assignment: String
        public let localSource: String?
    }

    /// Finished notation is output, not a new creative instruction. Only a
    /// separate task authorizes another model call; retain its source material.
    public static func compositionInput(chat: String, idea: String, fallback: String,
                                        parametersJSON: Data? = nil, sourceJSON: Data? = nil) throws -> CompositionInput {
        func isNotation(_ text: String) -> Bool {
            // Even malformed LilyPond must stay on the local error/recovery path.
            if (try? LilyPondSource.extract(text))?.contains("\\score") == true { return true }
            guard let data = try? interpretComposition(text),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return value["kind"] as? String == "score"
        }
        let task = visibleAssignment(chat: chat, idea: idea, fallback: fallback)
        if isNotation(task) { return CompositionInput(assignment: task, localSource: task) }
        var assignment = try buildAssignment(task, parametersJSON: parametersJSON, sourceJSON: sourceJSON)
        if !chat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, isNotation(idea) {
            assignment += "\n\nVORHANDENER NOTENTEXT ZUM BEARBEITUNGSAUFTRAG:\n" + idea
        }
        return CompositionInput(assignment: assignment, localSource: nil)
    }

    public static func buildAssignment(_ assignment: String, parametersJSON: Data? = nil, sourceJSON: Data? = nil) throws -> String {
        let parameters = try parametersJSON.map { try JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        let labels = [("ensemble", "Besetzung"), ("measures", "Takte"), ("meter", "Taktart"), ("tempo", "Tempo"), ("key", "Tonart")]
        let supplied = labels.compactMap { key, label -> String? in
            guard let value = parameters[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return label + ": " + value
        }
        var result = assignment + (supplied.isEmpty ? "" : "\n\n" + supplied.joined(separator: "\n"))
        if let sourceJSON {
            guard let source = try JSONSerialization.jsonObject(with: sourceJSON) as? [String: Any], let score = source["score"] else { throw APIError.badResponse("Die gewählte Vorlage enthält keine Partitur.") }
            _ = try validatedScore(JSONSerialization.data(withJSONObject: score))
            result += "\n\nVORHANDENES MUSIKALISCHES MATERIAL AUS " + (source["name"] as? String ?? "importierter Vorlage") + ":\n" + String(decoding: sourceJSON, as: UTF8.self)
        }
        return result
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

    public static func translateExisting(requestJSON: Data, apiKey: String,
                               progress: ((String) -> Void)? = nil,
                               completion: @escaping (Result<Data, Error>) -> Void) {
        do {
            let dto = try JSONDecoder().decode(RequestDTO.self, from: requestJSON)
            guard !(dto.composition ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !dto.model.isEmpty, !apiKey.isEmpty else {
                throw APIError.badResponse("Auftrag, Modell und API-Schlüssel fehlen.")
            }
            let request = CompositionRequest(assignment: dto.assignment, provider: dto.provider,
                model: dto.model, effort: dto.effort, key: apiKey)
            CompositionWorkflow().translateExisting(request, composition: dto.composition ?? "", priorInputTokens: dto.priorInputTokens ?? 0, priorOutputTokens: dto.priorOutputTokens ?? 0, priorCostUSD: dto.priorCostUSD ?? 0, progress: { stage, _ in
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

    @discardableResult
    public static func chat(requestJSON: Data, apiKey: String, compositionOnly: Bool = false,
                            completion: @escaping (Result<Data, Error>) -> Void) -> CoreRequestHandle {
        let client = APIClient()
        let handle = CoreRequestHandle(client: client)
        performChat(requestJSON: requestJSON, apiKey: apiKey, compositionOnly: compositionOnly, client: client, completion: completion)
        return handle
    }

    static func performChat(requestJSON: Data, apiKey: String, compositionOnly: Bool,
                            client: AIRequesting, completion: @escaping (Result<Data, Error>) -> Void) {
        do {
            let dto = try JSONDecoder().decode(RequestDTO.self, from: requestJSON)
            guard !dto.assignment.isEmpty, !apiKey.isEmpty else { throw APIError.emptyResponse }
            let options = try JSONSerialization.jsonObject(with: requestJSON) as? [String: Any] ?? [:]
            let dialogue = !compositionOnly && options["mode"] as? String == "dialogue"
            let prompt = compositionOnly ? ComposerPrompts.nativeCompositionPrompt(dto.assignment) : dialogue ? WorkspaceDialogue.prompt(message: dto.assignment, workspace: options["workspace"] as? String ?? "{}") : dto.assignment
            client.call(provider: dto.provider, model: dto.model, key: apiKey,
                effort: dto.effort, purpose: compositionOnly ? "composition" : "music-chat", system: ComposerPrompts.system, user: prompt,
                wantJSON: dialogue) { result in
                completion(result.flatMap { response in Result {
                    var diagnostic: [String: Any] = ["text": response.text, "provider": dto.provider.rawValue, "model": dto.model, "assignment": dto.assignment, "sentUserPrompt": prompt, "sentSystemPrompt": ComposerPrompts.system, "automaticTranslation": false, "reasoning": dto.effort.rawValue, "stage": "chat-completed",
                        "inputTokens": response.inputTokens, "outputTokens": response.outputTokens,
                        "estimatedCostUSD": APICost.estimate(provider: dto.provider, model: dto.model,
                            inputTokens: response.inputTokens, outputTokens: response.outputTokens)]
                    if dialogue { diagnostic["dialogue"] = try JSONSerialization.jsonObject(with: WorkspaceDialogue.decode(response.text)) }
                    if compositionOnly {
                        diagnostic["composition"] = response.text
                        diagnostic["compositionPrompt"] = prompt
                        diagnostic["requestedOutputFormat"] = "lilypond"
                        diagnostic["engineBuild"] = ComposerPrompts.engineBuild
                        diagnostic["engineVersion"] = ComposerPrompts.referenceVersion
                        let interpreted = (try? JSONSerialization.jsonObject(with: interpretComposition(response.text))) as? [String: Any] ?? ["kind": "unrecognized"]
                        diagnostic["outputFormat"] = interpreted["kind"]
                        diagnostic["stage"] = interpreted["kind"] as? String == "unrecognized" ? "composition-output-unrecognized" : "composition-completed"
                    }
                    return try JSONSerialization.data(withJSONObject: diagnostic)
                } })
            }
        } catch { completion(.failure(error)) }
    }

    private struct RequestDTO: Decodable {
        let composition: String?
        let priorInputTokens: Int?
        let priorOutputTokens: Int?
        let priorCostUSD: Double?
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
