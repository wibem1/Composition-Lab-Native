import Foundation
import XCTest
@testable import CompositionCore

final class WorkspaceWorkflowTests: XCTestCase {
    func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
    func testVisibleTaskAndExplicitReferenceAreShared() throws {
        XCTAssertEqual(CoreServices.visibleAssignment(chat: "Neu", idea: "Alt", fallback: "Fallback"), "Neu")
        XCTAssertEqual(CoreServices.visibleAssignment(chat: "  ", idea: "Idee", fallback: "Fallback"), "Idee")
        let score = Score(ti: "Vorlage", bpm: 96, ts: .init(n: 4, d: 4), k: "C major", sm: "", tr: [.init(nm: "Piano", ch: 0, pg: 0, nt: [[0, 1, 60, 80]], ct: nil, ev: nil)])
        let source = try json(["name": "Vorlage", "score": JSONSerialization.jsonObject(with: JSONEncoder().encode(score))])
        let prompt = try CoreServices.buildAssignment("Variieren", sourceJSON: source)
        XCTAssertTrue(prompt.hasPrefix("Variieren")); XCTAssertTrue(prompt.contains("Vorlage"))
        XCTAssertThrowsError(try CoreServices.buildAssignment("Test", sourceJSON: json(["name": "invalid"])))
    }
    func testFinishedViolinAndPianoIsLocalDespiteStalePianoSetting() throws {
        let source = "Erste Liebe – Violine und Klavier\n```lilypond\n\\version \"2.24.3\"\n\\score { << \\new Staff { c''4 } \\new PianoStaff << \\new Staff { c'4 } \\new Staff { c4 } >> >> }\n```"
        let input = try CoreServices.compositionInput(chat: "", idea: source, fallback: "Komponiere", parametersJSON: json(["ensemble": "Klavier"]))
        XCTAssertEqual(input.localSource, source)
        XCTAssertEqual(input.assignment, source)
        XCTAssertFalse(input.assignment.contains("Besetzung: Klavier"))
        XCTAssertEqual(try CoreServices.compositionInput(chat: source, idea: "", fallback: "").localSource, source)
    }
    func testExplicitRevisionRetainsSourceAndUserParameters() throws {
        let source = "\\score { \\new Staff { c'4 } }"
        let input = try CoreServices.compositionInput(chat: "Übertrage für Klavier solo", idea: source, fallback: "Alt", parametersJSON: json(["ensemble": "Klavier"]))
        XCTAssertNil(input.localSource)
        XCTAssertTrue(input.assignment.hasPrefix("Übertrage für Klavier solo"))
        XCTAssertTrue(input.assignment.contains("Besetzung: Klavier"))
        XCTAssertTrue(input.assignment.contains(source))
        let fresh = try CoreServices.compositionInput(chat: "Neue Fuge", idea: "Alte Idee", fallback: "Alt")
        XCTAssertNil(fresh.localSource)
        XCTAssertEqual(fresh.assignment, "Neue Fuge")
    }
    func testBackupPayloadFixtureUsesPortableSettings() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "backup-compatibility", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var payload = fixture["payload"] as! [String: Any]
        try CoreServices.validateBackup(json(payload))
        payload["version"] = 99
        XCTAssertThrowsError(try CoreServices.validateBackup(json(payload)))
    }
    func testDialogueRetainsExplicitSourcesAndRejectsInvalidSlots() throws {
        let response: [String: Any] = ["reply": "Neue Idee", "compositionAssignment": "Walzer", "sourceSlots": [2, 2, 1], "resolvedSettings": ["tempo": "88", "private": "discard"]]
        let decoded = try JSONSerialization.jsonObject(with: WorkspaceDialogue.decode(String(decoding: json(response), as: UTF8.self))) as! [String: Any]
        XCTAssertEqual(decoded["sourceSlots"] as? [Int], [1, 2])
        XCTAssertNil((decoded["resolvedSettings"] as? [String: Any])?["private"])
        XCTAssertThrowsError(try WorkspaceDialogue.decode("{\"reply\":\"Hi\",\"sourceSlots\":[11]}"))
        XCTAssertThrowsError(try WorkspaceDialogue.decode("{\"reply\":\"\"}"))
        XCTAssertTrue(WorkspaceDialogue.prompt(message: "Neue Idee", workspace: "{}" ).contains("erzeugt keine Partitur"))
    }
    func testLaboratoryContractsAndMotifBounds() throws {
        let score = Score(ti: "Motiv", bpm: 96, ts: .init(n: 4, d: 4), k: "C major", sm: "", tr: [.init(nm: "Piano", ch: 0, pg: 0, nt: [[0, 4, 60, 80]], ct: nil, ev: nil)])
        try LaboratoryWorkflow.validateMotif(scoreJSON: JSONEncoder().encode(score), measures: 1)
        var overflow = score; overflow.tr[0].nt.append([4, 1, 64, 80])
        XCTAssertThrowsError(try LaboratoryWorkflow.validateMotif(scoreJSON: JSONEncoder().encode(overflow), measures: 1))
        XCTAssertThrowsError(try LaboratoryWorkflow.prompt(kind: "motif", task: "", measures: 0))
        let original = "{\"title\":\"A — 𝄞\",\"source\":\"unchanged\"}"
        for kind in ["analysis", "compare", "revision", "route"] {
            XCTAssertTrue(try LaboratoryWorkflow.prompt(kind: kind, task: "Test", first: original).contains(original))
        }
    }
    func testRevisionSwapProtectsIdentityAndClearsRedoOnNewEdit() throws {
        func doc(_ id: String, _ n: Int) -> [String: Any] { ["identity": id, "document": ["value": n, "future": ["text": "𝄞"]]] }
        func step(_ operation: String, _ state: Any? = nil, _ slots: [Any]) throws -> [String: Any] {
            var request: [String: Any] = ["operation": operation, "slots": slots, "slot": 0]
            if let state { request["state"] = state }
            return try JSONSerialization.jsonObject(with: ScoreRevisionStore.step(json(request))) as! [String: Any]
        }
        let pushed = try step("push", nil, [doc("piece", 1)])
        XCTAssertThrowsError(try step("undo", pushed["state"], [doc("replacement", 2)]))
        let undo = try step("undo", pushed["state"], [doc("piece", 2)])
        XCTAssertEqual((undo["document"] as? [String: Any])?["value"] as? Int, 1)
        XCTAssertNotNil((undo["document"] as? [String: Any])?["future"])
        let redo = try step("redo", undo["state"], [doc("piece", 1)])
        XCTAssertEqual((redo["document"] as? [String: Any])?["value"] as? Int, 2)
        let edited = try step("push", undo["state"], [doc("piece", 1)])
        XCTAssertNil(try step("redo", edited["state"], [doc("piece", 3)])["document"])
        var state: Any? = nil
        for n in 0..<30 { state = try step("push", state, [doc("piece", n)])["state"] }
        XCTAssertEqual((state as? [String: Any])?["undo"].flatMap { $0 as? [Any] }?.count, 25)
    }
}
