import Foundation

/// Pure source policy shared by engraver adapters. No process, file, UI or AI.
enum LilyPondSource {
    static func match(_ pattern: String, in source: String) -> NSTextCheckingResult? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]).firstMatch(in: source, range: NSRange(location: 0, length: (source as NSString).length))
    }
    static func extract(_ text: String) throws -> String {
        let string = text as NSString
        let fence = match(#"```(?:lilypond|ly)?[^\S\r\n]*\r?\n([\s\S]*?)```"#, in: text)
        let source = (fence.map { string.substring(with: $0.range(at: 1)) } ?? text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.contains("\\version") || source.contains("\\score") else {
            throw APIError.badResponse("Dieses Stück enthält keinen LilyPond-Quelltext.")
        }
        return source + "\n"
    }
    static func maskedNotation(_ source: String) throws -> String {
        // Mask strings and comments without shifting offsets or line numbers.
        let masked = NSMutableString(string: source)
        let tokens = try NSRegularExpression(pattern: #"(?s)%\{.*?%\}|%[^\r\n]*|\"(?:\\.|[^\"\\])*\""#)
        for token in tokens.matches(in: source, range: NSRange(location: 0, length: masked.length)).reversed() {
            let value = (source as NSString).substring(with: token.range)
            let blank = value.utf16.map { ($0 == 10 || $0 == 13) ? $0 : 32 }
            masked.replaceCharacters(in: token.range, with: String(decoding: blank, as: UTF16.self))
        }
        return masked as String
    }
    static func prepare(_ source: String) throws -> String {
        let notation = try maskedNotation(source)
        let allowed = try NSRegularExpression(pattern: #"##[tf]\b|#\(set-global-staff-size\s+\d+(?:\.\d+)?\s*\)"#)
        let checked = allowed.stringByReplacingMatches(in: notation, range: NSRange(location: 0, length: (notation as NSString).length), withTemplate: " ")
        guard match(#"\\(?:include|includeSpecial|bookOutputName|bookOutputSuffix|applyContext|applyOutput|displayScheme|scheme|load)\b|\$|#(?!#[tf]\b|[-+]?\d+(?:\.\d+)?)"#, in: checked) == nil else {
            throw APIError.badResponse("Die LilyPond-Datei enthält externe Dateien, veränderte Ausgabepfade oder ausführbare Scheme-Ausdrücke. Für die direkte Ausgabe bitte reine Notation verwenden.")
        }
        guard let score = match(#"\\score\s*\{"#, in: notation) else { throw APIError.badResponse("Kein vollständiger LilyPond-Score vorhanden.") }
        let units = Array(notation.utf16)
        var depth = 1, end = NSMaxRange(score.range)
        while end < units.count && depth > 0 {
            if units[end] == 123 { depth += 1 }
            if units[end] == 125 { depth -= 1 }
            end += 1
        }
        guard depth == 0 else { throw APIError.badResponse("Die LilyPond-Score-Klammer ist nicht geschlossen.") }
        let directives = (match(#"\\layout\s*\{"#, in: notation) == nil ? "\n\\layout { }\n" : "") +
                         (match(#"\\midi\s*\{"#, in: notation) == nil ? "\n\\midi { }\n" : "")
        let result = NSMutableString(string: source)
        result.insert(directives, at: end - 1)
        return result as String
    }
    struct Point: Codable { let line: Int; let character: Int }
    struct Selection: Codable { let start: Int?; let length: Int?; let error: String? }

    static func selection(rendered: String, editor: String, from: Point, to: Point) -> Selection {
        func failure(_ reason: String) -> Selection { Selection(start: nil, length: nil, error: reason) }
        func normalize(_ value: String) -> String { value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n") }
        guard !rendered.isEmpty else { return failure("EmptySource") }
        guard normalize(rendered) == normalize(editor) else { return failure("StaleSource") }
        let full = editor as NSString
        let fence = match(#"```(?:lilypond|ly)?[^\S\r\n]*\r?\n([\s\S]*?)```"#, in: editor)
        let range = fence?.range(at: 1) ?? NSRange(location: 0, length: full.length)
        let raw = full.substring(with: range)
        let body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let leading = (raw as NSString).range(of: body).location
        guard leading != NSNotFound else { return failure("EmptySource") }
        let lines = body.components(separatedBy: "\n")
        func offset(_ point: Point) -> Int? {
            guard point.line > 0, point.line <= lines.count, point.character >= 0 else { return nil }
            let line = lines[point.line - 1].replacingOccurrences(of: "\r", with: "")
            let scalars = Array(line.unicodeScalars)
            guard point.character < scalars.count else { return nil }
            let prefix = String(String.UnicodeScalarView(scalars.prefix(point.character)))
            let preceding = lines.prefix(point.line - 1).reduce(0) { $0 + ($1 as NSString).length + 1 }
            return range.location + leading + preceding + (prefix as NSString).length
        }
        guard let a = offset(from), let b = offset(to) else { return failure("InvalidPosition") }
        return Selection(start: min(a,b), length: max(1, abs(b-a)+1), error: nil)
    }

    static func preview(pages: [String], renderID: String) throws -> String {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "ScorePreview", withExtension: "html", subdirectory: "Resources")
        #else
        let url = Bundle.main.url(forResource: "ScorePreview", withExtension: "html")
        #endif
        guard let url else { throw APIError.badResponse("Gemeinsame Notenansicht fehlt.") }
        let data = try JSONSerialization.data(withJSONObject: pages)
        let json = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "<", with: "\\u003c")
        let idData = try JSONSerialization.data(withJSONObject: [renderID])
        let id = String(decoding: idData, as: UTF8.self).dropFirst().dropLast()
        return try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "PAGES_VALUE", with: json)
            .replacingOccurrences(of: "RENDER_ID_VALUE", with: String(id))
    }

}
