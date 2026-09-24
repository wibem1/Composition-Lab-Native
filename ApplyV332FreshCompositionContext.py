from pathlib import Path

# Composition Lab Native 3.3.2 / Build 3302
# Context hygiene for NEW composition requests.
# The model still receives the full dialogue and workspace, but is explicitly
# required to treat a clearly new composition request as a fresh musical start.
# Existing idea remains authoritative only for explicit continuation/revision.

m = Path("Sources/MainViewController.swift")
s = m.read_text(encoding="utf-8")

anchor = '''        - Wenn der Nutzer diskutiert, analysiert oder vergleicht, antworte normal und ändere die Kompositionsidee nur dann, wenn das inhaltlich wirklich gemeint ist.
'''
insert = '''        - Wenn der Nutzer diskutiert, analysiert oder vergleicht, antworte normal und ändere die Kompositionsidee nur dann, wenn das inhaltlich wirklich gemeint ist.
        - WICHTIG ZUR KONTEXTTRENNUNG: Wenn der aktuelle Nutzerbeitrag eindeutig eine NEUE Komposition verlangt, behandle die neue compositionIdea als musikalischen Neustart. Die bisherige currentCompositionIdea und frühere Kompositionsideen im Gespräch sind dann nur Verlauf und KEINE musikalische Vorlage.
        - Übernimm bei einem neuen Kompositionsauftrag insbesondere keine bisherigen Motive, Begleitmuster, Formmodelle, Modulationswege, Dramaturgie oder Artikulationsideen, außer der Nutzer verlangt ausdrücklich eine Fortsetzung, Variante, Überarbeitung oder Bezugnahme.
        - Wenn der Nutzer dagegen ausdrücklich eine vorhandene Idee weiterentwickeln, verändern, variieren oder erneut umsetzen möchte, darf und soll die aktuelle editierbare Kompositionsidee als Grundlage verwendet werden.
'''
if anchor not in s:
    raise SystemExit("V3.3.2: MusicChat context anchor not found")
s=s.replace(anchor,insert,1)

# Diagnostics must identify the actual interface version.
s=s.replace('"interfaceVersion": "3.3.1"', '"interfaceVersion": "3.3.2"')
s=s.replace('"interfaceVersion": "3.0.9"', '"interfaceVersion": "3.3.2"')
s=s.replace('"interfaceVersion": "3.0.3"', '"interfaceVersion": "3.3.2"')
m.write_text(s,encoding="utf-8")

plist=Path("Info.plist")
p=plist.read_text(encoding="utf-8")
p=p.replace("<key>CFBundleShortVersionString</key><string>3.3.1</string>","<key>CFBundleShortVersionString</key><string>3.3.2</string>")
p=p.replace("<key>CFBundleVersion</key><string>3301</string>","<key>CFBundleVersion</key><string>3302</string>")
plist.write_text(p,encoding="utf-8")
print("Applied V3.3.2: fresh-context rule for genuinely new compositions.")
