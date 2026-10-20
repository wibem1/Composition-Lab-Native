import Foundation

/// Bounded committed-document undo/redo shared by both native adapters.
/// Slot identity prevents a history entry from replacing a different piece.
public enum ScoreRevisionStore {
    private struct Document: Codable { let identity: String; let document: JSONValue }
    private struct Entry: Codable { let slot: Int; let value: Document }
    private struct State: Codable { var undo: [Entry] = []; var redo: [Entry] = [] }
    private struct Request: Decodable {
        let operation: String
        let state: State?
        let slots: [Document?]
        let slot: Int?
    }
    public static func step(_ requestJSON: Data) throws -> Data {
        let request = try JSONDecoder().decode(Request.self, from: requestJSON)
        var state = request.state ?? State()
        var response: [String: Any] = [:]
        switch request.operation {
        case "push":
            guard let slot = request.slot, request.slots.indices.contains(slot), let value = request.slots[slot], !value.identity.isEmpty else { throw APIError.badResponse("Keine gültige Partiturrevision.") }
            state.undo.append(Entry(slot: slot, value: value))
            state.undo = Array(state.undo.suffix(25)); state.redo.removeAll()
        case "undo", "redo":
            let redo = request.operation == "redo"
            if let entry = (redo ? state.redo : state.undo).last {
                guard request.slots.indices.contains(entry.slot), let current = request.slots[entry.slot], current.identity == entry.value.identity else {
                    throw APIError.badResponse("Das ursprüngliche Stück dieser Partituränderung ist nicht mehr vorhanden.")
                }
                if redo { state.redo.removeLast(); state.undo.append(Entry(slot: entry.slot, value: current)) }
                else { state.undo.removeLast(); state.redo.append(Entry(slot: entry.slot, value: current)) }
                response["slot"] = entry.slot
                response["document"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry.value.document))
            }
        default: throw APIError.badResponse("Unbekannte Partiturrevision.")
        }
        response["state"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        return try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])
    }
}
