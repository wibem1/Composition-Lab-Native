import Foundation
import CompositionCore

enum BridgeService {
    // One process per request. Secrets arrive on stdin, never as process arguments
    // or temporary files. Stdout is NDJSON: progress then one final result.
    static func run() throws {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let obj = try JSONSerialization.jsonObject(with: input) as? [String: Any],
              let operation = obj["operation"] as? String else {
            throw NSError(domain: "BridgeService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Ungültiger Auftrag."])
        }
        func data(_ key: String) throws -> Data {
            guard let value = obj[key] else { throw NSError(domain: "BridgeService", code: 2) }
            return try JSONSerialization.data(withJSONObject: value)
        }
        func bytes() throws -> Data {
            guard let base64 = obj["data"] as? String, let value = Data(base64Encoded: base64) else {
                throw NSError(domain: "BridgeService", code: 3)
            }
            return value
        }
        let title = obj["title"] as? String ?? "Import"
        switch operation {
        case "version": send(["ok": true, "version": CoreServices.version, "titleEcho": title])
        case "model-catalog-step":
            let result = try CoreServices.modelCatalogStep(provider: obj["provider"] as? String ?? "",
                stateJSON: obj["state"] == nil ? nil : data("state"),
                pageJSON: obj["page"] == nil ? nil : data("page"))
            send(["ok": true, "catalog": try JSONSerialization.jsonObject(with: result)])
        case "recover-score":
            guard let response = obj["response"] as? String else { throw NSError(domain: "BridgeService", code: 6) }
            send(["ok": true, "score": try JSONSerialization.jsonObject(with: CoreServices.recoverScore(response: response))])
        case "midi": send(["ok": true, "data": try CoreServices.midi(scoreJSON: data("score")).base64EncodedString()])
        case "musicxml": send(["ok": true, "data": try CoreServices.musicXML(scoreJSON: data("score"), optionsJSON: obj["options"] is [String: Any] ? data("options") : nil).base64EncodedString()])
        case "import-midi": send(["ok": true, "score": try JSONSerialization.jsonObject(with: CoreServices.importMIDI(bytes(), title: title))])
        case "import-musicxml": send(["ok": true, "score": try JSONSerialization.jsonObject(with: CoreServices.importMusicXML(bytes(), title: title))])
        case "validate-workspace":
            try CoreServices.validateWorkspace(data("document")); send(["ok": true])
        case "validate-document":
            try CoreServices.validateDocument(data("document"))
            send(["ok": true])
        case "compose", "compose-source", "chat", "translate-existing":
            let semaphore = DispatchSemaphore(value: 0)
            let key = obj["apiKey"] as? String ?? ""
            let completion: (Result<Data, Error>) -> Void = { result in
                switch result {
                case .success(let output):
                    do { send(["ok": true, "result": try JSONSerialization.jsonObject(with: output)]) }
                    catch { send(["ok": false, "error": error.localizedDescription]) }
                case .failure(let error):
                    var response: [String: Any] = ["ok": false, "error": error.localizedDescription]
                    if let failure = error as? CoreCompositionError,
                       let diagnostic = try? JSONSerialization.jsonObject(with: failure.diagnosticJSON) {
                        response["diagnostic"] = diagnostic
                    }
                    send(response)
                }
                semaphore.signal()
            }
            if operation == "compose" {
                CoreServices.compose(requestJSON: try data("request"), apiKey: key,
                    progress: { send(["event": "progress", "stage": $0]) }, completion: completion)
            } else if operation == "translate-existing" {
                CoreServices.translateExisting(requestJSON: try data("request"), apiKey: key, progress: { send(["event": "progress", "stage": $0]) }, completion: completion)
            } else { CoreServices.chat(requestJSON: try data("request"), apiKey: key, compositionOnly: operation == "compose-source", completion: completion) }
            if semaphore.wait(timeout: .now() + 1900) == .timedOut {
                throw NSError(domain: "BridgeService", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "Zeitlimit der KI-Anfrage erreicht."])
            }
        default: throw NSError(domain: "BridgeService", code: 5,
                               userInfo: [NSLocalizedDescriptionKey: "Unbekannte Operation."])
        }
    }

    static func send(_ response: [String: Any]) {
        if let json = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]) {
            FileHandle.standardOutput.write(json + Data([10]))
        }
    }
}
