import Foundation
import XCTest
@testable import CompositionCore

final class CoreTests: XCTestCase {
    func testNativeCreativeRequestRequiresLilyPondForEveryProviderAndPreservesAssignment() throws {
        let assignment = "Pastorale für Violine und Violoncello im 6/8-Takt."
        let music = "```lilypond\n\\version \"2.24.3\"\n\\score { << \\new Staff { c''4 } \\new Staff { c4 } >> \\layout {} \\midi {} }\n```"
        for provider in Provider.allCases {
            let client = FakeAI([.success(LLMResponse(text: music, inputTokens: 10, outputTokens: 20))])
            let request = try JSONSerialization.data(withJSONObject: ["assignment": assignment, "provider": provider.rawValue, "model": "offline-model", "effort": "medium"])
            var captured: Result<Data, Error>?
            CoreServices.performChat(requestJSON: request, apiKey: "OFFLINE", compositionOnly: true, client: client) { captured = $0 }
            let diagnostic = try JSONSerialization.jsonObject(with: XCTUnwrap(captured).get()) as! [String: Any]
            XCTAssertEqual(client.calls.count, 1)
            XCTAssertTrue(client.calls[0].user.hasPrefix(assignment))
            XCTAssertTrue(client.calls[0].user.contains("LilyPond 2.24"))
            XCTAssertTrue(client.calls[0].user.contains("Kein ABC"))
            XCTAssertEqual(diagnostic["assignment"] as? String, assignment)
            XCTAssertEqual(diagnostic["sentUserPrompt"] as? String, client.calls[0].user)
            XCTAssertEqual(diagnostic["compositionPrompt"] as? String, client.calls[0].user)
            XCTAssertEqual(diagnostic["requestedOutputFormat"] as? String, "lilypond")
            XCTAssertEqual(diagnostic["composition"] as? String, music)
            let interpretation = try JSONSerialization.jsonObject(with: CoreServices.interpretComposition(music)) as! [String: Any]
            XCTAssertEqual(interpretation["kind"] as? String, "lilypond")
            XCTAssertTrue(try CoreServices.prepareLilyPond(interpretation["source"] as! String).contains("\\midi"))
        }
    }
    func testUnsupportedABCResponseIsPreservedAndMarkedWithoutAnotherRequest() throws {
        let abc = "```abc\nX:1\nT:Pastorale\nM:6/8\nL:1/8\nK:F\nF6|]\n```"
        let client = FakeAI([.success(LLMResponse(text: abc, inputTokens: 10, outputTokens: 20))])
        let request = try JSONSerialization.data(withJSONObject: ["assignment": "Pastorale", "provider": "gemini", "model": "offline", "effort": "medium"])
        var captured: Result<Data, Error>?
        CoreServices.performChat(requestJSON: request, apiKey: "OFFLINE", compositionOnly: true, client: client) { captured = $0 }
        let diagnostic = try JSONSerialization.jsonObject(with: XCTUnwrap(captured).get()) as! [String: Any]
        XCTAssertEqual(diagnostic["stage"] as? String, "composition-output-unrecognized")
        XCTAssertEqual(diagnostic["composition"] as? String, abc)
        XCTAssertEqual(client.calls.count, 1)
    }
    func testOrdinaryChatDoesNotReceiveCompositionFormatInstructions() throws {
        let client = FakeAI([.success(LLMResponse(text: "Antwort", inputTokens: 1, outputTokens: 1))])
        let request = try JSONSerialization.data(withJSONObject: ["assignment": "Erkläre einen Kanon", "provider": "gemini", "model": "offline", "effort": "medium"])
        CoreServices.performChat(requestJSON: request, apiKey: "OFFLINE", compositionOnly: false, client: client) { _ in }
        XCTAssertEqual(client.calls[0].user, "Erkläre einen Kanon")
    }
    private func score() -> Score {
        Score(ti: "Über die Grenze", bpm: 96, ts: TimeSignature(n: 4, d: 4), k: "C major",
              sm: "", tr: [Track(nm: "Piano", ch: 0, pg: 0,
              nt: [[0, 1, 60, 80, 0, 1], [1, 1, 64, 75, 0, 1], [2, 2, 67, 90, 0, 1]],
              ct: nil, ev: [NotationEvent(b: 0, t: "dyn", v: "p")])])
    }

    func testMIDIRoundTripPreservesNotesAndTempo() throws {
        let original = score()
        let data = try CoreServices.midi(scoreJSON: JSONEncoder().encode(original))
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "MThd")
        let result = try JSONDecoder().decode(Score.self, from: CoreServices.importMIDI(data, title: "fallback"))
        XCTAssertEqual(result.ti, original.ti)
        XCTAssertEqual(result.bpm, original.bpm, accuracy: 0.001)
        XCTAssertEqual(result.tr[0].nt, original.tr[0].nt)
    }

    func testMusicXMLRenderingDoesNotChangePlayback() throws {
        let original = score()
        let before = MIDIBuilder.build(original)
        let readable = try XCTUnwrap(MusicXMLBuilder.build(original, options: .readablePiano))
        let exact = try XCTUnwrap(MusicXMLBuilder.build(original, options: .midiNear))
        XCTAssertFalse(readable.isEmpty)
        XCTAssertFalse(exact.isEmpty)
        XCTAssertEqual(MIDIBuilder.build(original), before)
    }

    func testSoloStringClefsDoNotChangePitchOrPlayback() throws {
        for (program, name, sign, line) in [(40, "Violine", "G", 2), (41, "Viola", "C", 3), (42, "Cello", "F", 4), (43, "Kontrabass", "F", 4)] {
            var piece = score(); piece.tr[0].pg = program; piece.tr[0].nm = name
            let before = MIDIBuilder.build(piece)
            let xmlData = try XCTUnwrap(MusicXMLBuilder.build(piece, options: .midiNear))
            let xml = try XCTUnwrap(String(data: xmlData, encoding: .utf8))
            XCTAssertTrue(xml.contains("<clef><sign>\(sign)</sign><line>\(line)</line></clef>"), name)
            XCTAssertEqual(MIDIBuilder.build(piece), before)
            let imported = try MusicXMLParser.parse(data: xmlData, fallbackTitle: name)
            XCTAssertEqual(imported.tr[0].nt.map { $0[2] }, piece.tr[0].nt.map { $0[2] })
        }
    }

    func testWindowsNotationOptionsUseTheSameMacExporter() throws {
        let data = try JSONEncoder().encode(score())
        let before = try CoreServices.midi(scoreJSON: data)
        let options = MusicXMLDisplayOptions.midiNear
        let windows = try CoreServices.musicXML(scoreJSON: data, optionsJSON: JSONEncoder().encode(options))
        XCTAssertEqual(windows, MusicXMLBuilder.build(score(), options: options))
        XCTAssertEqual(try CoreServices.midi(scoreJSON: data), before)
    }

    func testMacWorkspaceFormatIsValidatedBySharedCore() throws {
        let item = HistoryItem(id: UUID(), time: Date(), title: "Test", provider: .openai, model: "test", concept: "Idee", score: score())
        var json: [String: Any] = ["format": "composition-lab-v6-project", "name": "Test", "activeSlot": 0,
            "slots": [try JSONSerialization.jsonObject(with: JSONEncoder().encode(item))],
            "settings": try JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings())), "history": []]
        try CoreServices.validateWorkspace(JSONSerialization.data(withJSONObject: json))
        json["activeSlot"] = 10
        XCTAssertThrowsError(try CoreServices.validateWorkspace(JSONSerialization.data(withJSONObject: json)))
    }

    func testExistingMusicXMLFixturesImportAndRoundTrip() throws {
        for name in ["musicxml-ev-roundtrip", "musicxml-musescore-tie-import", "musicxml-piano-two-staff-roundtrip"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "musicxml", subdirectory: "Fixtures"))
            let first = try MusicXMLParser.parse(data: Data(contentsOf: url), fallbackTitle: name)
            let exported = try XCTUnwrap(MusicXMLBuilder.build(first, options: .midiNear))
            let second = try MusicXMLParser.parse(data: exported, fallbackTitle: name)
            XCTAssertEqual(second.ti, first.ti)
            XCTAssertEqual(second.ts.n, first.ts.n)
            XCTAssertEqual(second.ts.d, first.ts.d)
            XCTAssertEqual(second.tr.flatMap { $0.nt }.map { $0[2] }.sorted(),
                           first.tr.flatMap { $0.nt }.map { $0[2] }.sorted(), name)
            XCTAssertEqual(Set(second.tr.flatMap { $0.ev ?? [] }.map { $0.t }),
                           Set(first.tr.flatMap { $0.ev ?? [] }.map { $0.t }), name)
        }
    }

    func testCLABRemainsReadableWithoutRewritingOriginal() throws {
        let document = CompositionLabDocument(title: "Altbestand", score: score(), concept: "Gedanke",
            provider: .anthropic, model: "test", measures: "1", meter: "4/4", tempo: "96",
            musicalKey: "C major", ensemble: "Piano", assignment: "Musik", sourceName: nil, sourceScore: nil)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        json["futureOptionalField"] = ["preserve": true]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        try CoreServices.validateDocument(data)
        let unchanged = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(unchanged["futureOptionalField"])
    }

    func testInvalidScoreAndCorruptFilesFailCleanly() throws {
        var invalid = score()
        invalid.tr[0].nt[0][2] = 128
        XCTAssertThrowsError(try CoreServices.midi(scoreJSON: JSONEncoder().encode(invalid)))
        XCTAssertThrowsError(try CoreServices.importMIDI(Data("bad midi".utf8), title: "invalid"))
        XCTAssertThrowsError(try CoreServices.importMusicXML(Data("<bad>".utf8), title: "invalid"))
    }

    func testWorkflowUsesFinishedCompositionThenTranslation() throws {
        let json = String(data: try JSONEncoder().encode(score()), encoding: .utf8)!
        let fake = FakeAI([.success(LLMResponse(text: "Fertiges Stück", inputTokens: 100, outputTokens: 200)),
                           .success(LLMResponse(text: json, inputTokens: 300, outputTokens: 400))])
        var received: CompositionResult?
        CompositionWorkflow(client: fake).compose(request()) { result in
            switch result { case .success(let work): received = work
            case .failure(let error): XCTFail(error.localizedDescription) }
        }
        let work = try XCTUnwrap(received)
        XCTAssertEqual(fake.calls.map { $0.purpose }, ["composition", "composition.technical-translation"])
        XCTAssertEqual(fake.calls.map { $0.wantJSON }, [false, true])
        XCTAssertEqual(fake.calls[0].user, ComposerPrompts.compositionPrompt("Ein Klavierstück"))
        XCTAssertEqual(fake.calls[1].user, ComposerPrompts.translationPrompt(composition: "Fertiges Stück"))
        XCTAssertEqual(work.inputTokens, 400)
        XCTAssertEqual(work.outputTokens, 600)
        XCTAssertNotNil(work.diagnostic["score"])
        XCTAssertEqual(work.diagnostic["composition"] as? String, "Fertiges Stück")
        let diagnostic = String(data: try JSONSerialization.data(withJSONObject: work.diagnostic), encoding: .utf8)!
        XCTAssertFalse(diagnostic.contains("TEST-KEY-DO-NOT-LOG"))
    }

    func testExistingCompositionIsTranslatedOnceWithoutRecomposition() throws {
        let json = String(data: try JSONEncoder().encode(score()), encoding: .utf8)!
        let music = "Schon fertige Musik\n```lilypond\n\\score { { c'4 d'4 } }\n```"
        let fake = FakeAI([.success(LLMResponse(text: json, inputTokens: 30, outputTokens: 40))])
        var received: CompositionResult?
        CompositionWorkflow(client: fake).translateExisting(request(), composition: music,
            priorInputTokens: 110, priorOutputTokens: 3810, priorCostUSD: 0.07664) { result in
            if case .success(let work) = result { received = work } else { XCTFail("Translation failed") }
        }
        let work = try XCTUnwrap(received)
        XCTAssertEqual(fake.calls.count, 1)
        XCTAssertEqual(fake.calls[0].purpose, "composition.technical-translation")
        XCTAssertEqual(fake.calls[0].user, ComposerPrompts.translationPrompt(composition: music))
        XCTAssertEqual(work.composition, music)
        XCTAssertEqual(work.inputTokens, 140); XCTAssertEqual(work.outputTokens, 3850)
        XCTAssertGreaterThanOrEqual(work.estimatedCostUSD, 0.07664)
        XCTAssertEqual(try CoreServices.midi(scoreJSON: JSONEncoder().encode(work.score)).prefix(4), Data("MThd".utf8))
    }

    func testFailedExistingTranslationPreservesTheFinishedMusic() {
        let fake = FakeAI([.success(LLMResponse(text: "bad JSON", inputTokens: 1, outputTokens: 2))])
        var failed = false
        CompositionWorkflow(client: fake).translateExisting(request(), composition: "Meine fertige Komposition") { result in
            if case .failure(let error) = result {
                failed = true
                XCTAssertEqual(error.diagnostic["composition"] as? String, "Meine fertige Komposition")
                XCTAssertEqual(error.diagnostic["scoreResponse"] as? String, "bad JSON")
            }
        }
        XCTAssertTrue(failed); XCTAssertEqual(fake.calls.count, 1)
    }

    func testWorkflowDoesNotTranslateAfterCreativeFailure() {
        let fake = FakeAI([.failure(APIError.emptyResponse)])
        var failed = false
        CompositionWorkflow(client: fake).compose(request()) { result in
            if case .failure(let error) = result {
                failed = true
                XCTAssertEqual(error.diagnostic["failedStage"] as? String, "composition-request")
            }
        }
        XCTAssertTrue(failed)
        XCTAssertEqual(fake.calls.count, 1)
    }

    func testTranslationFailureKeepsCompletedMusicAndRawResponse() {
        let fake = FakeAI([.success(LLMResponse(text: "Meine Komposition", inputTokens: 1, outputTokens: 2)),
                           .success(LLMResponse(text: "Kein JSON", inputTokens: 3, outputTokens: 4))])
        var failed = false
        CompositionWorkflow(client: fake).compose(request()) { result in
            if case .failure(let error) = result {
                failed = true
                XCTAssertEqual(error.diagnostic["composition"] as? String, "Meine Komposition")
                XCTAssertEqual(error.diagnostic["scoreResponse"] as? String, "Kein JSON")
            }
        }
        XCTAssertTrue(failed)
    }

    func testTranslatorAliasesAndRangeEventsKeepNotesAndExpression() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(score())) as? [String: Any])
        var tracks = object["tr"] as! [[String: Any]]
        tracks[0]["ev"] = [
            ["t":"slur", "staff":1, "ranges":[[0.0,4.0]]],
            ["b":0, "t":"tempo", "text":"Für Klavier – mäßig", "qpm":96],
            ["b":0, "t":"dynamic", "staff":1, "v":"p"],
            ["b":0, "t":"crescendo", "staff":1, "to":2],
            ["b":4, "t":"fermata", "staff":1]
        ] as [[String: Any]]
        // Explicit staff assignments, as in a two-staff translator response.
        tracks[0]["nt"] = [[0.0,1,60,80,1,1],[1.0,1,64,75,1,1],[2.0,2,67,90,1,1]]
        object["tr"] = tracks
        let recovered = try JSONDecoder().decode(Score.self, from: CoreServices.recoverScore(
            response: String(data: JSONSerialization.data(withJSONObject: object), encoding: .utf8)!))
        XCTAssertEqual(recovered.tr[0].nt, tracks[0]["nt"] as? [[Double]])
        XCTAssertEqual(recovered.tr[0].ev?.first?.e, 2)
        XCTAssertEqual(recovered.tr[0].ev?.first?.st, 1)
        XCTAssertEqual(recovered.tr[0].ev?.first(where: { $0.t == "tempo" })?.n, 96)
        XCTAssertEqual(recovered.tr[0].ev?.first(where: { $0.t == "tempo" })?.v, "Für Klavier – mäßig")
        XCTAssertEqual(recovered.tr[0].ev?.first(where: { $0.t == "wedge" })?.e, 2)
        XCTAssertEqual(recovered.tr[0].ev?.first(where: { $0.v == "fermata" })?.b, 2)
        let xml = String(data: try XCTUnwrap(MusicXMLBuilder.build(recovered)), encoding: .utf8)!
        XCTAssertTrue(xml.contains("<slur")); XCTAssertTrue(xml.contains("<fermata"))
        XCTAssertTrue(xml.contains("<p/>"))
    }

    func testAlreadyMergedTiesDoNotCreateDanglingTies() throws {
        let input = #"{"ti":"Test","bpm":96,"ts":{"n":4,"d":4},"k":"C","sm":"","tr":[{"nm":"Piano","ch":0,"pg":0,"nt":[[0,2.5,64,80,1,1]],"ev":[{"t":"tie","staff":1,"ranges":[[0,2.5]]}]}]}"#
        let score = try ScoreDecoder.decode(Data(input.utf8))
        XCTAssertEqual(score.tr[0].nt[0][1], 2.5)
        XCTAssertEqual(score.tr[0].ev?.count, 0)
    }

    func testMissingEventBeatHasConcretePath() {
        let input = #"{"ti":"Test","bpm":96,"ts":{"n":4,"d":4},"k":"C","sm":"","tr":[{"nm":"Piano","ch":0,"pg":0,"nt":[[0,1,64,80]],"ev":[{"t":"dyn","v":"p"}]}]}"#
        XCTAssertThrowsError(try ScoreDecoder.decode(Data(input.utf8))) { error in
            XCTAssertTrue(error.localizedDescription.contains("tr[0].ev[0]"))
        }
    }

    private func request() -> CompositionRequest {
        CompositionRequest(assignment: "Ein Klavierstück", provider: .anthropic,
                           model: "test", effort: .high, key: "TEST-KEY-DO-NOT-LOG")
    }
}

private final class FakeAI: AIRequesting {
    struct Call { let purpose: String; let wantJSON: Bool; let user: String }
    var calls: [Call] = []
    private var responses: [Result<LLMResponse, Error>]
    init(_ responses: [Result<LLMResponse, Error>]) { self.responses = responses }
    func call(provider: Provider, model: String, key: String, effort: Effort, purpose: String,
              system: String, user: String, wantJSON: Bool, completion: @escaping APIClient.Completion) {
        calls.append(Call(purpose: purpose, wantJSON: wantJSON, user: user))
        guard !responses.isEmpty else { XCTFail("Unexpected API call"); return }
        completion(responses.removeFirst())
    }
}
