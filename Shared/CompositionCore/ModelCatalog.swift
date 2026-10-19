import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider catalog policy. The native adapters own HTTP transport and credentials;
/// this module owns pagination, validation, deduplication and model metadata.
struct CatalogModel: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var details: String
}

struct ModelCatalogState: Codable, Sendable {
    let provider: Provider
    var cursor = ""
    var seenCursors: [String] = []
    var models: [CatalogModel] = []
    var pageCount = 0
    var complete = false

    var request: [String: Any] {
        let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let url: String, header: String, prefix: String
        var headers: [String: String] = [:]
        switch provider {
        case .openai:
            url = "https://api.openai.com/v1/models" + (cursor.isEmpty ? "" : "?after=" + encoded)
            header = "Authorization"; prefix = "Bearer "
        case .anthropic:
            url = "https://api.anthropic.com/v1/models?limit=1000" + (cursor.isEmpty ? "" : "&after_id=" + encoded)
            header = "x-api-key"; prefix = ""; headers["anthropic-version"] = "2023-06-01"
        case .gemini:
            url = "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000" + (cursor.isEmpty ? "" : "&pageToken=" + encoded)
            header = "x-goog-api-key"; prefix = ""
        }
        return ["url": url, "keyHeader": header, "keyPrefix": prefix, "headers": headers]
    }

    mutating func consume(_ data: Data) throws {
        guard !complete, pageCount < 500,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root[provider == .gemini ? "models" : "data"] as? [[String: Any]] else {
            throw APIError.badResponse("Unvollständige Modellliste. Die bisherige Liste bleibt erhalten.")
        }
        var found = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        for item in items {
            guard var id = item[provider == .gemini ? "name" : "id"] as? String, !id.isEmpty else {
                throw APIError.badResponse("Ein Modell enthält keine Kennung.")
            }
            if provider == .gemini && id.hasPrefix("models/") { id = String(id.dropFirst(7)) }
            guard !id.isEmpty else { throw APIError.badResponse("Ein Modell enthält keine Kennung.") }
            let name = item[provider == .gemini ? "displayName" : "display_name"] as? String ?? id
            var details: [String] = []
            if let value = item["description"] as? String { details.append(value) }
            if let value = item["supportedGenerationMethods"] as? [String] { details.append("Funktionen: " + value.joined(separator: ", ")) }
            if let value = item["owned_by"] as? String { details.append("Anbieter: " + value) }
            for field in ["inputTokenLimit", "outputTokenLimit", "max_input_tokens", "max_tokens", "lifecycle"] {
                if let value = item[field] { details.append(field + ": " + String(describing: value)) }
            }
            if let value = item["capabilities"] as? [String: [String: Any]] {
                details.append("Funktionen: " + value.filter { $0.value["supported"] as? Bool == true }.keys.sorted().joined(separator: ", "))
            }
            found[id] = CatalogModel(id: id, name: name, details: details.joined(separator: "\n"))
        }
        let hasMore = root["has_more"] as? Bool == true
        let next = provider == .gemini ? root["nextPageToken"] as? String ?? "" :
            (hasMore ? root["last_id"] as? String ?? items.last?["id"] as? String ?? "" : "")
        guard !(provider != .gemini && hasMore && next.isEmpty) else {
            throw APIError.badResponse("Unvollständige Modellliste: nächste Seite fehlt.")
        }
        guard next.isEmpty || (!seenCursors.contains(next) && pageCount < 499) else {
            throw APIError.badResponse("Wiederholte oder zu viele Modellseiten. Die bisherige Liste bleibt erhalten.")
        }
        guard !next.isEmpty || !found.isEmpty else { throw APIError.badResponse("Der Provider hat keine verfügbaren Modelle gemeldet.") }
        models = found.values.sorted {
            let order = $0.name.caseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        pageCount += 1; cursor = next; complete = next.isEmpty
        if !next.isEmpty { seenCursors.append(next) }
    }
}

/// Native Mac transport. Catalog semantics are the same state machine called by
/// Windows through CoreServices; no API key is part of its serializable state.
final class NativeModelCatalogClient: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func list(provider: Provider, key: String, completion: @escaping @Sendable (Result<[CatalogModel], Error>) -> Void) {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(APIError.badResponse("Bitte zuerst den API-Schlüssel dieses Providers eintragen."))); return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let deadline = Date().addingTimeInterval(45)
        @Sendable func load(_ state: ModelCatalogState) {
            guard Date() < deadline else { session.invalidateAndCancel(); completion(.failure(APIError.badResponse("Zeitlimit der Modellabfrage erreicht."))); return }
            let plan = state.request
            var request = URLRequest(url: URL(string: plan["url"] as! String)!)
            request.setValue((plan["keyPrefix"] as! String) + key, forHTTPHeaderField: plan["keyHeader"] as! String)
            for (name, value) in plan["headers"] as! [String: String] { request.setValue(value, forHTTPHeaderField: name) }
            session.dataTask(with: request) { data, response, error in
                do {
                    guard error == nil else { throw APIError.badResponse("Keine Verbindung zum Provider. Die bisherige Liste bleibt erhalten.") }
                    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), let data else {
                        throw APIError.badResponse("Modellliste konnte nicht geladen werden. API-Schlüssel und Provider-Zugriff prüfen.")
                    }
                    var next = state; try next.consume(data)
                    if next.complete { session.finishTasksAndInvalidate(); completion(.success(next.models)) }
                    else { load(next) }
                } catch { session.invalidateAndCancel(); completion(.failure(error)) }
            }.resume()
        }
        load(ModelCatalogState(provider: provider))
    }
}
