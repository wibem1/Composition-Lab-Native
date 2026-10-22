import Foundation

/// Provider and engraver adapters around the shared musical acceptance rules.
/// The caller explicitly requests a repair; ordinary imports only scan.
final class NativeRegisterRepairService {
    typealias Transport = (String, @escaping (Result<Data, Error>) -> Void) -> Void
    let compiler: NativeLilyPondCompiler
    init(compiler: NativeLilyPondCompiler) { self.compiler = compiler }

    func repair(source: String, transport: @escaping Transport,
                completion: @escaping (Result<NativeLocalComposition, Error>) -> Void) {
        let local = NativeLocalCompositionService(compiler: compiler)
        local.interpret(source) { result in
            do {
                guard let before = try result.get() else { throw APIError.badResponse("Kein lokal lesbares Stück für die Oktavprüfung.") }
                let beforeJSON = try JSONEncoder().encode(before.score)
                let issues = try RegisterReview.inspect(scoreJSON: beforeJSON)
                guard let values = try JSONSerialization.jsonObject(with: issues) as? [[String: Any]], !values.isEmpty else {
                    completion(.success(before)); return
                }
                let instruction = RegisterReview.instruction + "\nBEFUND:\n" + String(decoding: issues, as: UTF8.self) + "\nORIGINAL:\n" + source
                transport(instruction) { response in
                    do {
                        let data = try response.get()
                        let diagnostic = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                        guard let text = diagnostic["text"] as? String else { throw APIError.emptyResponse }
                        local.interpret(text) { interpreted in
                            do {
                                guard let after = try interpreted.get() else { throw APIError.badResponse("Korrektur enthält keine lokal lesbare Musik.") }
                                try RegisterReview.validateRepair(before: beforeJSON, after: JSONEncoder().encode(after.score), source: text)
                                var metadata = after.metadata
                                metadata["originalLilyPond"] = .string(source)
                                metadata["lilyPondSource"] = .string(text)
                                metadata["octaveReview"] = .object(["status": .string("corrected"), "repairAICalls": .number(1),
                                    "response": try JSONDecoder().decode(JSONValue.self, from: data)])
                                completion(.success(NativeLocalComposition(score: after.score, metadata: metadata)))
                            } catch { completion(.failure(error)) }
                        }
                    } catch { completion(.failure(error)) }
                }
            } catch { completion(.failure(error)) }
        }
    }
}
