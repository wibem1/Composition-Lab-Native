import Foundation

struct LLMResponse {
    var text: String
    var inputTokens: Int
    var outputTokens: Int
}

enum APIError: LocalizedError {
    case badResponse(String)
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .badResponse(let s): return s
        case .emptyResponse: return "Die KI hat keine Textantwort geliefert."
        case .invalidJSON: return "Kein valides JSON in der Modellantwort gefunden."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 600
        cfg.timeoutIntervalForResource = 900
        return URLSession(configuration: cfg)
    }()

    typealias Completion = (Result<LLMResponse, Error>) -> Void

    func call(provider: Provider, model: String, key: String, effort: Effort,
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

    private func perform(_ request: URLRequest, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data, let http = response as? HTTPURLResponse else {
                completion(.failure(APIError.badResponse("Keine gültige HTTP-Antwort."))); return
            }
            completion(.success((data, http)))
        }.resume()
    }

    private func callAnthropic(model: String, key: String, effort: Effort, system: String, user: String,
                               completion: @escaping Completion) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(APIError.badResponse("Ungültige Anthropic-URL."))); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String:Any] = [
            "model": model,
            "max_tokens": 32000,
            "output_config": ["effort": effort.rawValue],
            "system": system,
            "messages": [["role":"user", "content":user]]
        ]
        do { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        catch { completion(.failure(error)); return }
        perform(req) { result in
            do {
                let (data, http) = try result.get()
                let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any] ?? [:]
                if !(200..<300).contains(http.statusCode) {
                    let err = ((obj["error"] as? [String:Any])?["message"] as? String) ?? "Anthropic HTTP \(http.statusCode)"
                    throw APIError.badResponse(err)
                }
                let parts = obj["content"] as? [[String:Any]] ?? []
                let text = parts.filter { ($0["type"] as? String) == "text" }.compactMap { $0["text"] as? String }.joined()
                let usage = obj["usage"] as? [String:Any] ?? [:]
                guard !text.isEmpty else { throw APIError.emptyResponse }
                completion(.success(LLMResponse(text: text,
                                                inputTokens: usage["input_tokens"] as? Int ?? 0,
                                                outputTokens: usage["output_tokens"] as? Int ?? 0)))
            } catch { completion(.failure(error)) }
        }
    }

    private func callGemini(model: String, key: String, effort: Effort, system: String, user: String, wantJSON: Bool,
                            completion: @escaping Completion) {
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        var comps = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent")
        comps?.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = comps?.url else { completion(.failure(APIError.badResponse("Ungültige Gemini-URL."))); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var generation: [String:Any] = [
            "maxOutputTokens": 32000,
            "thinkingConfig": ["thinkingLevel": effort.rawValue.uppercased()]
        ]
        if wantJSON { generation["responseMimeType"] = "application/json" }
        let body: [String:Any] = [
            "system_instruction": ["parts":[["text":system]]],
            "contents": [["role":"user", "parts":[["text":user]]]],
            "generationConfig": generation
        ]
        do { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        catch { completion(.failure(error)); return }
        perform(req) { result in
            do {
                let (data, http) = try result.get()
                let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any] ?? [:]
                if !(200..<300).contains(http.statusCode) {
                    let err = ((obj["error"] as? [String:Any])?["message"] as? String) ?? "Gemini HTTP \(http.statusCode)"
                    throw APIError.badResponse(err)
                }
                let candidates = obj["candidates"] as? [[String:Any]] ?? []
                let content = candidates.first?["content"] as? [String:Any]
                let parts = content?["parts"] as? [[String:Any]] ?? []
                let text = parts.compactMap { $0["text"] as? String }.joined()
                let usage = obj["usageMetadata"] as? [String:Any] ?? [:]
                guard !text.isEmpty else { throw APIError.emptyResponse }
                let candidateTokens = usage["candidatesTokenCount"] as? Int ?? 0
                let thinkingTokens = usage["thoughtsTokenCount"] as? Int ?? 0
                completion(.success(LLMResponse(text: text,
                                                inputTokens: usage["promptTokenCount"] as? Int ?? 0,
                                                outputTokens: candidateTokens + thinkingTokens)))
            } catch { completion(.failure(error)) }
        }
    }

    private func callOpenAI(model: String, key: String, effort: Effort, system: String, user: String, wantJSON: Bool,
                            completion: @escaping Completion) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(APIError.badResponse("Ungültige OpenAI-URL."))); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        var body: [String:Any] = [
            "model": model,
            "messages": [
                ["role":"system", "content":system],
                ["role":"user", "content":user]
            ],
            "reasoning_effort": effort.rawValue
        ]
        if wantJSON { body["response_format"] = ["type":"json_object"] }
        do { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        catch { completion(.failure(error)); return }
        perform(req) { result in
            do {
                let (data, http) = try result.get()
                let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any] ?? [:]
                if !(200..<300).contains(http.statusCode) {
                    let err = ((obj["error"] as? [String:Any])?["message"] as? String) ?? "OpenAI HTTP \(http.statusCode)"
                    throw APIError.badResponse(err)
                }
                let choices = obj["choices"] as? [[String:Any]] ?? []
                let message = choices.first?["message"] as? [String:Any]
                let text = message?["content"] as? String ?? ""
                let usage = obj["usage"] as? [String:Any] ?? [:]
                guard !text.isEmpty else { throw APIError.emptyResponse }
                completion(.success(LLMResponse(text: text,
                                                inputTokens: usage["prompt_tokens"] as? Int ?? 0,
                                                outputTokens: usage["completion_tokens"] as? Int ?? 0)))
            } catch { completion(.failure(error)) }
        }
    }

    func extractJSON(_ text: String) throws -> Data {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
        guard let a = s.firstIndex(of: "{"), let b = s.lastIndex(of: "}"), a <= b else {
            throw APIError.invalidJSON
        }
        return Data(s[a...b].utf8)
    }
}
