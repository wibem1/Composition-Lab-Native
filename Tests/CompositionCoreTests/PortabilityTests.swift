import Foundation
import XCTest
@testable import CompositionCore

final class PortabilityTests: XCTestCase {
    private func piece() -> HistoryItem {
        HistoryItem(id: UUID(), time: Date(), title: "Original", provider: .gemini, model: "future-model",
            concept: "Unverändertes Original", score: Score(ti: "Original", bpm: 96, ts: TimeSignature(n: 4, d: 4),
                k: "C major", sm: "", tr: [Track(nm: "Piano", ch: 0, pg: 0, nt: [[0, 1, 60, 80]])]))
    }
    func testWindowsHistoryExtensionsSurviveMacRoundTrip() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(piece())) as? [String: Any])
        let extra: [String: Any] = ["directLilyPond": true, "lilyPondSource": "\\score { c'4 }",
            "sourceMidiData": "TVRoZA==", "description": "Geänderter Entwurf", "assignment": "Originalauftrag",
            "octaveReview": ["status": "issues", "issues": [["minimum": 12, "beats": [0, 1.5]]]],
            "futureExtension": ["empty": NSNull(), "list": [true, "Ü", 2.5]]]
        for (key, value) in extra { json[key] = value }
        let item = try JSONDecoder().decode(HistoryItem.self, from: JSONSerialization.data(withJSONObject: json))
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? NSDictionary)
        for (key, value) in extra { XCTAssertEqual(saved[key] as? NSObject, value as? NSObject, key) }
        XCTAssertEqual(item.concept, "Unverändertes Original")
        XCTAssertNil(saved["extraFields"])
    }
    func testCLABExtensionsCannotOverrideTypedMusic() throws {
        let score = piece().score
        var doc = CompositionLabDocument(title: "Original", score: score, concept: "Original", provider: .gemini,
            model: "future-model", measures: "", meter: "", tempo: "", musicalKey: "", ensemble: "", assignment: "Auftrag")
        doc.extraFields = ["title": .string("Falscher Titel"), "lilyPondSource": .string("c'4"),
                           "originalMusic": .object(["revision": .number(2)])]
        let data = try JSONEncoder().encode(doc)
        try CoreServices.validateDocument(data)
        let restored = try JSONDecoder().decode(CompositionLabDocument.self, from: data)
        XCTAssertEqual(restored.title, "Original")
        XCTAssertEqual(restored.extraFields["lilyPondSource"], .string("c'4"))
        XCTAssertEqual(restored.extraFields["originalMusic"], doc.extraFields["originalMusic"])
    }
    func testCatalogPreservesAllModelsAndProviderCapabilities() throws {
        var catalog = ModelCatalogState(provider: .gemini)
        try catalog.consume(Data(#"{"models":[{"name":"models/future","displayName":"Zukunft","supportedGenerationMethods":["generateContent"]}],"nextPageToken":"token +/"}"#.utf8))
        XCTAssertFalse(catalog.complete)
        XCTAssertTrue((catalog.request["url"] as? String)?.contains("pageToken=token%20%2B%2F") == true)
        XCTAssertEqual(catalog.request["keyHeader"] as? String, "x-goog-api-key")
        try catalog.consume(Data(#"{"models":[{"name":"models/embedding","supportedGenerationMethods":["embedContent"]},{"name":"models/future","displayName":"Zukunft"}]}"#.utf8))
        XCTAssertTrue(catalog.complete)
        XCTAssertEqual(catalog.models.count, 2)
        XCTAssertTrue(catalog.models.contains { $0.id == "embedding" && $0.details.contains("embedContent") })
    }
    func testCatalogRejectsIncompleteAndRepeatedPages() throws {
        for invalid in [#"{}"#, #"{"data":[]}"#, #"{"data":[{"display_name":"Missing ID"}]}"#] {
            var state = ModelCatalogState(provider: .anthropic)
            XCTAssertThrowsError(try state.consume(Data(invalid.utf8)))
        }
        var state = ModelCatalogState(provider: .anthropic)
        let page = Data(#"{"data":[{"id":"future"}],"has_more":true,"last_id":"again"}"#.utf8)
        try state.consume(page)
        XCTAssertThrowsError(try state.consume(page))
    }
    func testCatalogWireBoundaryHasNoSecretFields() throws {
        let response = try CoreServices.modelCatalogStep(provider: "openai")
        let text = try XCTUnwrap(String(data: response, encoding: .utf8))
        XCTAssertFalse(text.contains("apiKey"))
        XCTAssertTrue(text.contains("keyHeader"))
        XCTAssertThrowsError(try CoreServices.modelCatalogStep(provider: "unknown"))
        let wrongProvider = try JSONEncoder().encode(ModelCatalogState(provider: .gemini))
        XCTAssertThrowsError(try CoreServices.modelCatalogStep(provider: "openai", stateJSON: wrongProvider))
    }
    func testPortableWorkspaceRetainsExtensionsAndChat() throws {
        var workspace = CompositionWorkspace(name: "Über die Grenze", activeSlot: 0, slots: [piece(), nil], settings: AppSettings(), history: [piece()])
        workspace.chat = "Unveränderter Chat"; workspace.concept = "Quellentwurf"
        workspace.extraFields = ["version": .number(1), "futureWorkspaceField": .object(["source": .string("Original")])]
        let data = try JSONEncoder().encode(workspace)
        try CoreServices.validateWorkspace(data)
        let restored = try JSONDecoder().decode(CompositionWorkspace.self, from: data)
        XCTAssertEqual(restored.chat, workspace.chat)
        XCTAssertEqual(restored.extraFields["futureWorkspaceField"], workspace.extraFields["futureWorkspaceField"])
        XCTAssertEqual(restored.slots.count, 2)
        XCTAssertNil(restored.slots[1])
    }

    func testAssignmentUsesOnlyVisibleUserParameters() throws {
        let original = "  Ein freies Stück\nmit zwei Stimmen.  "
        XCTAssertEqual(try CoreServices.buildAssignment(original), original)
        let empty = try JSONEncoder().encode(["measures": "", "tempo": " ", "key": ""])
        XCTAssertEqual(try CoreServices.buildAssignment(original, parametersJSON: empty), original)
        let supplied = try JSONEncoder().encode(["measures": "48", "tempo": "80", "key": "d-Moll"])
        XCTAssertEqual(try CoreServices.buildAssignment(original, parametersJSON: supplied), original + "\n\nTakte: 48\nTempo: 80\nTonart: d-Moll")
    }

}
