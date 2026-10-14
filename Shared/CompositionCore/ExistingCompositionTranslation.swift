import Foundation

extension CompositionWorkflow {
    /// Translate an already finished work once; never call the creative composer again.
    func translateExisting(_ request: CompositionRequest, composition: String,
                           priorInputTokens: Int = 0, priorOutputTokens: Int = 0, priorCostUSD: Double = 0,
                           progress: @escaping (CompositionStage, [String: Any]) -> Void = { _, _ in },
                           completion: @escaping (Result<CompositionResult, CompositionFailure>) -> Void) {
        let prompt = ComposerPrompts.translationPrompt(composition: composition)
        let initial: [String: Any] = ["format": "composition-lab-native-diagnostic", "coreVersion": CoreServices.version,
            "entryPoint": "existing-composition", "stage": CompositionStage.translation.rawValue,
            "assignment": request.assignment, "provider": request.provider.rawValue, "model": request.model,
            "reasoning": request.effort.rawValue, "composition": composition, "translationPrompt": prompt,
            "compositionInputTokens": priorInputTokens, "compositionOutputTokens": priorOutputTokens,
            "compositionEstimatedCostUSD": priorCostUSD]
        progress(.translation, initial)
        client.call(provider: request.provider, model: request.model, key: request.key, effort: request.effort,
                    purpose: "composition.technical-translation", system: ComposerPrompts.system, user: prompt,
                    wantJSON: true) { response in
            var diagnostic = initial
            do {
                let technical = try response.get()
                diagnostic["scoreResponse"] = technical.text
                let input = priorInputTokens + technical.inputTokens, output = priorOutputTokens + technical.outputTokens
                let cost = priorCostUSD + APICost.estimate(provider: request.provider, model: request.model,
                    inputTokens: technical.inputTokens, outputTokens: technical.outputTokens)
                diagnostic["inputTokens"] = input; diagnostic["outputTokens"] = output; diagnostic["estimatedCostUSD"] = cost
                diagnostic["translationInputTokens"] = technical.inputTokens; diagnostic["translationOutputTokens"] = technical.outputTokens
                let score = try ScoreDecoder.decode(APIClient.shared.extractJSON(technical.text))
                try ScoreValidation.validate(score)
                diagnostic["score"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(score))
                diagnostic["stage"] = CompositionStage.completed.rawValue
                completion(.success(CompositionResult(composition: composition, score: score, inputTokens: input,
                    outputTokens: output, estimatedCostUSD: cost, diagnostic: diagnostic)))
            } catch {
                diagnostic["failedStage"] = CompositionStage.translation.rawValue
                diagnostic["stage"] = CompositionStage.failed.rawValue; diagnostic["error"] = error.localizedDescription
                completion(.failure(CompositionFailure(underlying: error, diagnostic: diagnostic)))
            }
        }
    }
}
