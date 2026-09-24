from pathlib import Path

# Composition Lab Native 3.3.0 / Build 3300
# Composition Engine 2.0: Klangvorstellung -> Komposition -> technische Realisation.
# This patch is deliberately applied AFTER the complete V3.0.9 reconstruction.

models = Path("Sources/Models.swift")
s = models.read_text(encoding="utf-8")

s = s.replace(
    "// Eingefrorener musikalischer Kern: entspricht Engine Build 14 der APK/iPad-Version.\n    static let engineBuild = 14",
    "// Composition Engine 2.0: Klangvorstellung vor Notation und technischer Realisation.\n    static let engineBuild = 20",
    1
)

start = s.find("    static let system = \"\"\"\n")
end = s.find("    static let technical = \"\"\"\n", start)
if start < 0 or end < 0:
    raise SystemExit("V3.3.0: ComposerPrompts system/concept block not found")

new_head = r'''    static let system = """
    Du bist ein eigenständiger Komponist. Denke zuerst in hörbarer Musik: Klang, Geste, Bewegung,
    Spannung, Dichte, Register, Phrasierung und dramaturgischer Entwicklung. Formale und technische
    Entscheidungen dienen dieser Klangvorstellung und dürfen sie nicht durch schematische Muster ersetzen.
    """

    static func conceptPrompt(_ assignment: String) -> String {
        """
        Entwickle für den folgenden Kompositionsauftrag ausschließlich eine prägnante KLANGVORSTELLUNG:

        \(assignment)

        Beschreibe die Musik so, wie sie innerlich gehört und erlebt werden soll:
        - charakteristische Klangidee und musikalische Geste
        - Bewegung, Energie, Spannung und Entspannung
        - Entwicklung von Dichte, Register, Farbe und Dynamik
        - Kontraste, Phrasierung und dramaturgischer Verlauf
        - das Verhältnis der Stimmen bzw. Instrumente zueinander

        VERBOTEN IN DIESEM SCHRITT:
        - keine Notenschrift und keine Notennamen
        - kein LilyPond, ABC, MusicXML, MIDI, JSON oder Programmcode
        - keine Pitch-Listen, Event-Listen oder taktweise Codierung
        - keine technische Partitur-Realisierung
        - keine schematische Formanalyse als Ersatz für eine Klangvorstellung

        Die Beschreibung soll konkret genug sein, um eine eigenständige Komposition anzuregen,
        aber offen genug, damit der eigentliche Kompositionsschritt musikalisch frei arbeiten kann.

        Antworte ausschließlich mit der Klangvorstellung.
        """
    }

'''
s = s[:start] + new_head + s[end:]

technical_anchor = '''    static let technical = """
    NOTATION UND AUSGABE:
'''
technical_replacement = '''    static let technical = """
    COMPOSITION ENGINE 2.0 – KOPF UND HAND:

    Komponiere jetzt aus der vorgegebenen Klangvorstellung ein vollständiges, eigenständiges Musikstück.
    Die Klangvorstellung ist kein Text, der mechanisch illustriert werden soll, sondern die hörbare
    musikalische Identität des Stücks.

    KOMPONIERE ZUERST:
    - entwickle charakteristische Motive, Gesten und Stimmen aus der Klangvorstellung
    - gestalte Spannung, Kontrast, Phrasierung, Register und Dichte über den gesamten Verlauf
    - entwickle und transformiere Material, statt kurze Muster nur zu wiederholen
    - behandle Begleitstimmen als musikalisch sinnvolle Stimmen, nicht als automatische Füllmuster
    - vermeide stereotype Arpeggio-, Alberti-, Achtel- oder Akkordmuster, sofern sie nicht aus der
      konkreten Klangidee musikalisch notwendig sind
    - halte die verlangte Länge, Besetzung, Taktart, Tonart und das Tempo ein, soweit sie vorgegeben sind

    REALISIERE DANACH TECHNISCH:
    Die JSON-Ausgabe ist ausschließlich die technische Darstellung der bereits komponierten Musik.
    Erfinde im technischen Schritt keine Ersatzmusik und vereinfache die Komposition nicht aus Bequemlichkeit.

    NOTATION UND AUSGABE:
'''
if technical_anchor not in s:
    raise SystemExit("V3.3.0: technical prompt anchor not found")
s = s.replace(technical_anchor, technical_replacement, 1)
models.write_text(s, encoding="utf-8")

main = Path("Sources/MainViewController.swift")
m = main.read_text(encoding="utf-8")
m = m.replace('"interfaceVersion": "3.0.9"', '"interfaceVersion": "3.3.0"')
m = m.replace(
    'view.window?.title = "Composition Lab · Projekt: \\(projectName) · V5.0.12"',
    'let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"\n        view.window?.title = "Composition Lab · Projekt: \\(projectName) · V\\(version)"'
)
main.write_text(m, encoding="utf-8")

plist = Path("Info.plist")
p = plist.read_text(encoding="utf-8")
p = p.replace("<key>CFBundleShortVersionString</key><string>3.2.9</string>",
              "<key>CFBundleShortVersionString</key><string>3.3.0</string>")
p = p.replace("<key>CFBundleVersion</key><string>3209</string>",
              "<key>CFBundleVersion</key><string>3300</string>")
plist.write_text(p, encoding="utf-8")

print("Applied V3.3.0: Composition Engine 2.0 Klangvorstellung -> Komposition -> technische Realisation.")
