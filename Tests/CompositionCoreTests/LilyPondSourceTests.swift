import Foundation
import XCTest
@testable import CompositionCore

final class LilyPondSourceTests: XCTestCase {
    func testFinishedOriginalIsUnchanged() throws {
        let source = "\\version \"2.24.0\"\n\\header { title = \"Übung\" tagline = ##f }\n\\score { { c'4 d' e' f' } \\layout {} \\midi {} }\n"
        XCTAssertEqual(try LilyPondSource.prepare(source), source)
        XCTAssertEqual(try LilyPondSource.extract("Einleitung\n```lilypond\n" + source + "```"), source)
    }
    func testOutputDirectivesIgnoreMisleadingCommentsAndStrings() throws {
        let source = "% \\score { fake }\n\\header { title = \"{ \\midi {} }\" }\n\\score { { c'4 } }\n"
        let result = try LilyPondSource.prepare(source)
        XCTAssertTrue(result.hasPrefix("% \\score { fake }\n"))
        XCTAssertTrue(result.hasSuffix("\\layout { }\n\n\\midi { }\n}\n"))
    }
    func testUnsafeAndIncompleteSourcesFail() throws {
        for source in ["\\bookOutputName \"outside\" \\score { { c4 } }", "\\score { c4 } #(system \"anything\")", "\\include \"private.ly\" \\score { c4 }", "\\score { c4 } $(ly:gulp-file \"private\")", "\\score { { c4 }"] {
            XCTAssertThrowsError(try LilyPondSource.prepare(source))
        }
    }
    func testPastoraleDiagnosticAcceptsLiteralSpacingMomentUnchanged() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "pastorale-violin-cello", withExtension: "ly", subdirectory: "Fixtures"))
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("#(ly:make-moment 1/16)"))
        XCTAssertEqual(try LilyPondSource.prepare(source), source)
        XCTAssertEqual(try LilyPondSource.prepare(source.replacingOccurrences(of: "1/16)", with: "1 16)")),
                       source.replacingOccurrences(of: "1/16)", with: "1 16)"))
    }
    func testSpacingMomentDoesNotAllowExecutableArguments() throws {
        for expression in ["#(ly:make-moment (system \"anything\") 16)",
                           "#(ly:make-moment 1/0)", "#(ly:make-moment 1 0)",
                           "#(ly:make-moment 1/16 extra)", "#(ly:make-moment 1/16) #(system \"anything\")"] {
            XCTAssertThrowsError(try LilyPondSource.prepare("\\score { { c'4 } \\layout {} \\midi {} } " + expression))
        }
    }
    func testSharedSelectionNormalizesOnlyLineEndings() throws {
        let source = "c'4 d'4\r\n<e' g'>2\r\n"
        let editor = source.replacingOccurrences(of: "\r\n", with: "\n")
        let range = LilyPondSource.selection(rendered: source, editor: editor,
            from: .init(line: 2, character: 0), to: .init(line: 2, character: 1))
        XCTAssertEqual(range.start, 8); XCTAssertEqual(range.length, 2)
        XCTAssertEqual(LilyPondSource.selection(rendered: source, editor: editor + "x",
            from: .init(line: 1, character: 0), to: .init(line: 1, character: 0)).error, "StaleSource")
    }
    func testSharedSelectionHandlesTabsUnicodeAndFences() throws {
        let source = "Intro\n```lilypond\n\\version \"2.24.0\"\n\t% Ü 🎵\n\tc'4 d'4\n```"
        let selected = LilyPondSource.selection(rendered: source, editor: source,
            from: .init(line: 3, character: 1), to: .init(line: 3, character: 1))
        XCTAssertEqual(selected.start, (source as NSString).range(of: "c'4").location)
        let unicode = "x🎵c'4"
        let afterSymbol = LilyPondSource.selection(rendered: unicode, editor: unicode,
            from: .init(line: 1, character: 2), to: .init(line: 1, character: 2))
        XCTAssertEqual(afterSymbol.start, 3)
    }
    func testSharedPreviewHasBothNativeMessageAdapters() throws {
        let html = try LilyPondSource.preview(pages: ["<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"], renderID: "test-id")
        XCTAssertTrue(html.contains("window.webkit")); XCTAssertTrue(html.contains("window.chrome"))
        XCTAssertFalse(html.contains("PAGES_VALUE")); XCTAssertFalse(html.contains("RENDER_ID_VALUE"))
        XCTAssertTrue(html.contains("character:Number(m[2])"))
    }
    func testLocalInterpretationNeverNeedsTechnicalAI() throws {
        for (text, kind) in [("\\score { { c'4 } }", "lilypond"), ("Ein bloßer Formplan", "unrecognized")] {
            let result = try XCTUnwrap(JSONSerialization.jsonObject(with: CoreServices.interpretComposition(text)) as? [String: Any])
            XCTAssertEqual(result["kind"] as? String, kind)
        }
    }

}
