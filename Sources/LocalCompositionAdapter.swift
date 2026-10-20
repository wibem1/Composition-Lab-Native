import Foundation

struct NativeLocalComposition {
    let score: Score
    let metadata: [String: JSONValue]
}

/// Native engraver orchestration; format interpretation is shared with Windows.
/// Input and output retain the exact creative answer. There is no AI fallback.
final class NativeLocalCompositionService {
    let compiler: NativeLilyPondCompiler
    init(compiler: NativeLilyPondCompiler) { self.compiler = compiler }
    func interpret(_ original: String, completion: @escaping (Result<NativeLocalComposition?, Error>) -> Void) {
        do {
            let json = try JSONSerialization.jsonObject(with: CoreServices.interpretComposition(original)) as! [String: Any]
            if json["kind"] as? String == "lilypond", let source = json["source"] as? String {
                compiler.compile(source) { result in
                    completion(result.flatMap { output in Result {
                        var score = try MIDIParser.parse(data: output.midi, fallbackTitle: "Komposition")
                        if let title = LilyPondSource.match(#"\btitle\s*=\s*\"([^\"]+)\""#, in: source) {
                            score.ti = (source as NSString).substring(with: title.range(at: 1))
                        }
                        try ScoreValidation.validate(score)
                        return NativeLocalComposition(score: score, metadata: [
                            "directLilyPond": .bool(true), "sourceMidiData": .string(output.midi.base64EncodedString()),
                            "lilyPondSource": .string(original), "description": .string(original),
                            "octaveReview": .object(["status": .string((try JSONSerialization.jsonObject(with: RegisterReview.inspect(scoreJSON: JSONEncoder().encode(score))) as! [[String: Any]]).isEmpty ? "passed" : "issues"),
                                "issues": try JSONDecoder().decode(JSONValue.self, from: RegisterReview.inspect(scoreJSON: JSONEncoder().encode(score))), "repairAICalls": .number(0)])])
                    } })
                }
            } else if json["kind"] as? String == "score", let value = json["score"] {
                let score = try JSONDecoder().decode(Score.self, from: JSONSerialization.data(withJSONObject: value))
                completion(.success(NativeLocalComposition(score: score, metadata: [:])))
            } else { completion(.success(nil)) }
        } catch { completion(.failure(error)) }
    }
}
