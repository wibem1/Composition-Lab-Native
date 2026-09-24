from pathlib import Path

# Composition Lab Native 3.3.1 / Build 3301
# Complete AI communication logging at the central APIClient boundary.
# Every APIClient.call is logged, independent of feature/entry point.
# Secrets/API keys are deliberately NEVER written to diagnostics.

api = Path("Sources/APIClient.swift")
s = api.read_text(encoding="utf-8")

anchor = "final class APIClient {\n"
if anchor not in s:
    raise SystemExit("V3.3.1: APIClient anchor not found")

logger = r'''final class AICommunicationLog {
    static let shared = AICommunicationLog()
    private let queue = DispatchQueue(label: "CompositionLab.AICommunicationLog")
    private var entries: [[String: Any]] = []
    private var sequence = 0

    func begin(provider: Provider, model: String, effort: Effort,
               system: String, user: String, wantJSON: Bool) -> Int {
        queue.sync {
            sequence += 1
            entries.append([
                "sequence": sequence,
                "startedAt": ISO8601DateFormatter().string(from: Date()),
                "provider": provider.rawValue,
                "model": model,
                "reasoning": effort.rawValue,
                "wantJSON": wantJSON,
                "systemPrompt": system,
                "userPrompt": user,
                "status": "request-sent"
            ])
            return sequence
        }
    }

    func finish(_ id: Int, response: LLMResponse) {
        queue.sync {
            guard let i = entries.firstIndex(where: { ($0["sequence"] as? Int) == id }) else { return }
            entries[i]["completedAt"] = ISO8601DateFormatter().string(from: Date())
            entries[i]["status"] = "response-received"
            entries[i]["responseText"] = response.text
            entries[i]["inputTokens"] = response.inputTokens
            entries[i]["outputTokens"] = response.outputTokens
        }
    }

    func fail(_ id: Int, error: Error) {
        queue.sync {
            guard let i = entries.firstIndex(where: { ($0["sequence"] as? Int) == id }) else { return }
            entries[i]["completedAt"] = ISO8601DateFormatter().string(from: Date())
            entries[i]["status"] = "failed"
            entries[i]["error"] = error.localizedDescription
        }
    }

    func snapshot() -> [[String: Any]] { queue.sync { entries } }
    func reset() { queue.sync { entries.removeAll(); sequence = 0 } }
}

'''
s = s.replace(anchor, logger + anchor, 1)

old = '''    func call(provider: Provider, model: String, key: String, effort: Effort,
              system: String, user: String, wantJSON: Bool, completion: @escaping Completion) {
        switch provider {
        case .anthropic:
            callAnthropic(model: model, key: key, effort: effort, system: system, user: user, completion: completion)
        case .gemini:
            callGemini(model: model, key: key, effort: effort, system: system, user: user, wantJSON: wantJSON, completion: completion)
        case .openai:
            callOpenAI(model: model, key: key, effort: effort, system: system, user: user, wantJSON: wantJSON, completion: completion)
        }
    }
'''
new = '''    func call(provider: Provider, model: String, key: String, effort: Effort,
              system: String, user: String, wantJSON: Bool, completion: @escaping Completion) {
        let logID = AICommunicationLog.shared.begin(provider: provider, model: model, effort: effort,
                                                    system: system, user: user, wantJSON: wantJSON)
        let loggedCompletion: Completion = { result in
            switch result {
            case .success(let response):
                AICommunicationLog.shared.finish(logID, response: response)
            case .failure(let error):
                AICommunicationLog.shared.fail(logID, error: error)
            }
            completion(result)
        }
        switch provider {
        case .anthropic:
            callAnthropic(model: model, key: key, effort: effort, system: system, user: user, completion: loggedCompletion)
        case .gemini:
            callGemini(model: model, key: key, effort: effort, system: system, user: user, wantJSON: wantJSON, completion: loggedCompletion)
        case .openai:
            callOpenAI(model: model, key: key, effort: effort, system: system, user: user, wantJSON: wantJSON, completion: loggedCompletion)
        }
    }
'''
if old not in s:
    raise SystemExit("V3.3.1: APIClient.call block not found")
s = s.replace(old, new, 1)
api.write_text(s, encoding="utf-8")

main = Path("Sources/MainViewController.swift")
m = main.read_text(encoding="utf-8")
old_save = '''    @objc private func saveDiagnosticPressed() {
        guard let d=lastDiagnostic, JSONSerialization.isValidJSONObject(d), let data=try? JSONSerialization.data(withJSONObject:d,options:[.prettyPrinted,.sortedKeys]) else {
'''
new_save = '''    @objc private func saveDiagnosticPressed() {
        guard var d=lastDiagnostic else {
            status("Noch keine Diagnosedatei vorhanden. Bitte zuerst mit der KI arbeiten.",good:false); return
        }
        d["aiCommunication"] = AICommunicationLog.shared.snapshot()
        d["aiCommunicationLogging"] = "complete-central-APIClient-log; API keys and authorization secrets excluded"
        d["interfaceVersion"] = "3.3.1"
        guard JSONSerialization.isValidJSONObject(d), let data=try? JSONSerialization.data(withJSONObject:d,options:[.prettyPrinted,.sortedKeys]) else {
'''
if old_save not in m:
    raise SystemExit("V3.3.1: saveDiagnosticPressed anchor not found")
m = m.replace(old_save, new_save, 1)
main.write_text(m, encoding="utf-8")

plist = Path("Info.plist")
p = plist.read_text(encoding="utf-8")
p = p.replace("<key>CFBundleShortVersionString</key><string>3.3.0</string>",
              "<key>CFBundleShortVersionString</key><string>3.3.1</string>")
p = p.replace("<key>CFBundleVersion</key><string>3300</string>",
              "<key>CFBundleVersion</key><string>3301</string>")
plist.write_text(p, encoding="utf-8")

print("Applied V3.3.1: complete central AI communication logging.")
