import Foundation

/// Platform-independent two-call composition pipeline. The second call translates
/// the finished work; it does not introduce a new musical draft or composition strategy.
protocol AIRequesting {
    func call(provider: Provider, model: String, key: String, effort: Effort, purpose: String,
              system: String, user: String, wantJSON: Bool, completion: @escaping APIClient.Completion)
}

extension APIClient: AIRequesting {}

struct CompositionRequest {
    var assignment: String
    var provider: Provider
    var model: String
    var effort: Effort
    var key: String
}

enum CompositionStage: String {
    case composition = "composition-request"
    case translation = "technical-translation-request"
    case completed
    case failed
}

struct CompositionResult {
    let composition: String
    let score: Score
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double
    let diagnostic: [String: Any]
}

struct CompositionFailure: Error, LocalizedError {
    let underlying: Error
    let diagnostic: [String: Any]
    var errorDescription: String? { underlying.localizedDescription }
}

final class CompositionWorkflow {
    let client: AIRequesting
    init(client: AIRequesting = APIClient.shared) { self.client = client }

    func compose(_ request: CompositionRequest,
                 progress: @escaping (CompositionStage, [String: Any]) -> Void = { _, _ in },
                 completion: @escaping (Result<CompositionResult, CompositionFailure>) -> Void) {
        let prompt = ComposerPrompts.compositionPrompt(request.assignment)
        let initial: [String: Any] = [
            "format": "composition-lab-native-diagnostic",
            "coreVersion": CoreServices.version,
            "engineBuild": ComposerPrompts.engineBuild,
            "engineVersion": ComposerPrompts.referenceVersion,
            "stage": CompositionStage.composition.rawValue,
            "assignment": request.assignment, "compositionPrompt": prompt,
            "provider": request.provider.rawValue, "model": request.model,
            "reasoning": request.effort.rawValue
        ]
        progress(.composition, initial)
        client.call(provider: request.provider, model: request.model, key: request.key,
                    effort: request.effort, purpose: "composition", system: ComposerPrompts.system,
                    user: prompt, wantJSON: false) { first in
            switch first {
            case .failure(let error):
                Self.fail(error, diagnostic: initial, completion: completion)
            case .success(let creative):
                let composition = creative.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !composition.isEmpty else {
                    Self.fail(APIError.emptyResponse, diagnostic: initial, completion: completion)
                    return
                }
                let translation = ComposerPrompts.translationPrompt(composition: composition)
                var diagnostic = initial
                diagnostic["stage"] = CompositionStage.translation.rawValue
                diagnostic["composition"] = composition
                diagnostic["compositionInputTokens"] = creative.inputTokens
                diagnostic["compositionOutputTokens"] = creative.outputTokens
                diagnostic["translationPrompt"] = translation
                progress(.translation, diagnostic)
                // Capture an immutable snapshot so each request owns its diagnostic.
                let translationDiagnostic = diagnostic
                self.client.call(provider: request.provider, model: request.model, key: request.key,
                                 effort: request.effort, purpose: "composition.technical-translation",
                                 system: ComposerPrompts.system, user: translation, wantJSON: true) { second in
                    switch second {
                    case .failure(let error):
                        Self.fail(error, diagnostic: translationDiagnostic, completion: completion)
                    case .success(let technical):
                        var final = translationDiagnostic
                        final["scoreResponse"] = technical.text
                        final["translationInputTokens"] = technical.inputTokens
                        final["translationOutputTokens"] = technical.outputTokens
                        let input = creative.inputTokens + technical.inputTokens
                        let output = creative.outputTokens + technical.outputTokens
                        let cost = APICost.estimate(provider: request.provider, model: request.model,
                                                   inputTokens: input, outputTokens: output)
                        final["inputTokens"] = input
                        final["outputTokens"] = output
                        final["estimatedCostUSD"] = cost
                        do {
                            let json = try APIClient.shared.extractJSON(technical.text)
                            let score = try ScoreDecoder.decode(json)
                            try ScoreValidation.validate(score)
                            final["score"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(score))
                            final["stage"] = CompositionStage.completed.rawValue
                            progress(.completed, final)
                            completion(.success(CompositionResult(composition: composition, score: score,
                                inputTokens: input, outputTokens: output, estimatedCostUSD: cost,
                                diagnostic: final)))
                        } catch { Self.fail(error, diagnostic: final, completion: completion) }
                    }
                }
            }
        }
    }

    private static func fail(_ error: Error, diagnostic: [String: Any],
                             completion: (Result<CompositionResult, CompositionFailure>) -> Void) {
        var failed = diagnostic
        failed["failedStage"] = failed["stage"]
        failed["stage"] = CompositionStage.failed.rawValue
        failed["error"] = error.localizedDescription
        completion(.failure(CompositionFailure(underlying: error, diagnostic: failed)))
    }
}

/// Technical bounds only. No musical changes, quantization or aesthetic judgement.
enum ScoreValidation {
    static func validate(_ score: Score) throws {
        guard score.bpm.isFinite, score.bpm > 0,
              score.ts.n > 0, score.ts.n <= 255,
              [1, 2, 4, 8, 16, 32, 64, 128].contains(score.ts.d),
              !score.tr.isEmpty, score.tr.count < 65_535 else {
            throw APIError.badResponse("Ungültiges Tempo, Taktmaß oder Spurenanzahl.")
        }
        let maxBeat = Double(Int32.max) / Double(MIDIBuilder.ppq)
        for track in score.tr {
            guard (0...15).contains(track.ch), (0...127).contains(track.pg) else {
                throw APIError.badResponse("Ungültiger MIDI-Kanal oder Programmwert.")
            }
            for note in track.nt {
                guard note.count >= 4, note.allSatisfy({ $0.isFinite }),
                      note[0] >= 0, note[1] > 0, (0...127).contains(note[2]),
                      (0...127).contains(note[3]), note[0] + note[1] < maxBeat,
                      (note.count <= 5 || (note[5] > 0 && note[0] + note[1] * note[5] < maxBeat)) else {
                    throw APIError.badResponse("Ungültige Notendaten.")
                }
            }
            for control in track.ct ?? [] {
                guard control.count >= 3, control.allSatisfy({ $0.isFinite }),
                      control[0] >= 0, control[0] < maxBeat else {
                    throw APIError.badResponse("Ungültige Controllerdaten.")
                }
            }
            for event in track.ev ?? [] {
                guard event.b.isFinite, event.b >= 0, event.b < maxBeat,
                      event.e.map({ $0.isFinite && $0 >= 0 && $0 < maxBeat }) ?? true,
                      event.n.map({ $0.isFinite }) ?? true else {
                    throw APIError.badResponse("Ungültige Notationsereignisse.")
                }
            }
            for event in track.me ?? [] {
                guard event.b.isFinite, event.b >= 0, event.b < maxBeat else {
                    throw APIError.badResponse("Ungültige MIDI-Ereignisse.")
                }
            }
        }
    }
}
