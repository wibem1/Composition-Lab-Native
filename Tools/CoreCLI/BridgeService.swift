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
        case "build-assignment":
            let assignment = CoreServices.visibleAssignment(chat: obj["chatInput"] as? String ?? "", idea: obj["idea"] as? String ?? "", fallback: obj["assignment"] as? String ?? "")
            send(["ok": true, "assignment": try CoreServices.buildAssignment(assignment,
                parametersJSON: obj["parameters"] == nil ? nil : data("parameters"), sourceJSON: obj["source"] == nil || obj["source"] is NSNull ? nil : data("source"))])
        case "validate-backup":
            try CoreServices.validateBackup(data("document")); send(["ok": true])
        case "score-revision":
            send(["ok": true, "revision": try JSONSerialization.jsonObject(with: ScoreRevisionStore.step(data("request")))])
        case "lab-prompt":
            send(["ok": true, "prompt": try LaboratoryWorkflow.prompt(kind: obj["kind"] as? String ?? "", task: obj["task"] as? String ?? "",
                first: obj["first"] as? String ?? "", second: obj["second"] as? String ?? "", measures: obj["measures"] as? Int ?? 4,
                tempo: obj["tempo"] as? String ?? "", ensemble: obj["ensemble"] as? String ?? "", style: obj["style"] as? String ?? "")])
        case "validate-motif":
            try LaboratoryWorkflow.validateMotif(scoreJSON: data("score"), measures: obj["measures"] as? Int ?? 4)
            send(["ok": true])
        case "register-review":
            let issues = try RegisterReview.inspect(scoreJSON: data("score"))
            send(["ok": true, "issues": try JSONSerialization.jsonObject(with: issues), "instruction": RegisterReview.instruction])
        case "validate-register-repair":
            try RegisterReview.validateRepair(before: data("before"), after: data("after"), source: obj["source"] as? String ?? "")
            send(["ok": true])
        case "playback-midi":
            send(["ok": true, "data": try CoreServices.playbackMIDICopy(bytes(), velocityFactor: obj["velocityFactor"] as? Double ?? 1,
                targetBPM: obj["targetBPM"] as? Double).base64EncodedString()])
        case "interpret-composition":
            send(["ok": true, "interpretation": try JSONSerialization.jsonObject(with: CoreServices.interpretComposition(obj["source"] as? String ?? ""))])
        case "source-selection":
            let selection = try CoreServices.sourceSelection(rendered: obj["rendered"] as? String ?? "", editor: obj["editor"] as? String ?? "",
                fromLine: obj["line"] as? Int ?? 0, fromCharacter: obj["character"] as? Int ?? -1,
                toLine: obj["endLine"] as? Int ?? 0, toCharacter: obj["endCharacter"] as? Int ?? -1)
            send(["ok": true, "selection": try JSONSerialization.jsonObject(with: selection)])
        case "prepare-lilypond":
            send(["ok": true, "source": try CoreServices.prepareLilyPond(obj["source"] as? String ?? "")])
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
