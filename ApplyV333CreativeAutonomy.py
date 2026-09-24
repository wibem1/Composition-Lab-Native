from pathlib import Path

# Composition Lab Native 3.3.3 / Build 3303
# Engine 2.1: creative autonomy.
# No compositional coaching, recipes, prohibitions or style heuristics are added
# by the engine. The AI receives the user's assignment and, if present, the
# user's/current musical idea. Technical constraints exist only for serialization.

models=Path("Sources/Models.swift")
s=models.read_text(encoding="utf-8")

s=s.replace("static let engineBuild = 20","static let engineBuild = 21",1)

start=s.find('    static let system = """\n')
end=s.find('    static let technical = """\n',start)
if start < 0 or end < 0:
    raise SystemExit("V3.3.3: ComposerPrompts system block not found")

head=r'''    static let system = """
    Du bist ein eigenständiger Komponist.
    """

'''
s=s[:start]+head+s[end:]

old='''    COMPOSITION ENGINE 2.0 – KOPF UND HAND:

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

'''
new='''    COMPOSITION ENGINE 2.1 – TECHNISCHE REALISATION:

    Komponiere das vom Nutzer verlangte Musikstück eigenständig.
    Musikalische Entscheidungen triffst du selbst. Die folgenden Regeln betreffen ausschließlich
    die technische Darstellung der von dir komponierten Musik.

'''
if old not in s:
    raise SystemExit("V3.3.3: compositional coaching block not found")
s=s.replace(old,new,1)
models.write_text(s,encoding="utf-8")

main=Path("Sources/MainViewController.swift")
m=main.read_text(encoding="utf-8")
# Remove V3.3.2's engine-side semantic steering. New-vs-continuation remains
# visible in history but is not converted into compositional prescriptions.
for line in [
'        - WICHTIG ZUR KONTEXTTRENNUNG: Wenn der aktuelle Nutzerbeitrag eindeutig eine NEUE Komposition verlangt, behandle die neue compositionIdea als musikalischen Neustart. Die bisherige currentCompositionIdea und frühere Kompositionsideen im Gespräch sind dann nur Verlauf und KEINE musikalische Vorlage.\n',
'        - Übernimm bei einem neuen Kompositionsauftrag insbesondere keine bisherigen Motive, Begleitmuster, Formmodelle, Modulationswege, Dramaturgie oder Artikulationsideen, außer der Nutzer verlangt ausdrücklich eine Fortsetzung, Variante, Überarbeitung oder Bezugnahme.\n',
'        - Wenn der Nutzer dagegen ausdrücklich eine vorhandene Idee weiterentwickeln, verändern, variieren oder erneut umsetzen möchte, darf und soll die aktuelle editierbare Kompositionsidee als Grundlage verwendet werden.\n'
]:
    m=m.replace(line,"")
m=m.replace('"interfaceVersion": "3.3.2"','"interfaceVersion": "3.3.3"')
main.write_text(m,encoding="utf-8")

plist=Path("Info.plist")
p=plist.read_text(encoding="utf-8")
p=p.replace("<key>CFBundleShortVersionString</key><string>3.3.2</string>","<key>CFBundleShortVersionString</key><string>3.3.3</string>")
p=p.replace("<key>CFBundleVersion</key><string>3302</string>","<key>CFBundleVersion</key><string>3303</string>")
plist.write_text(p,encoding="utf-8")
print("Applied V3.3.3: Engine 2.1 creative autonomy; technical rules only.")
