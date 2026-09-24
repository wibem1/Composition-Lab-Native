from pathlib import Path
import re, subprocess

root = Path(__file__).resolve().parents[1]
patches = [
"ApplyWorkspaceLayoutFix.py","ApplyCompositionLab2.py","ApplyV6SlotsState.py","ApplyV6MainLayout.py","ApplyV6MainLayoutFix.py","ApplyV6CompileFixes.py",
"ApplyV63MainLayout.py","ApplyV63CardLabels.py","ApplyV64Layout.py","ApplyV63TechnicalWorkspace.py","ApplyV65Polish.py","ApplyV65PlayerSync.py",
"ApplyV651Fix.py","ApplyV652Volume.py","ApplyV662BottomAndSlotMenu.py","ApplyV663Workflow.py","ApplyFastScrollFix.py","ApplyV664Performance.py",
"ApplyV667AsyncBridge.py","ApplyV668PianoSplitAndMeasures.py","ApplyV669ConceptAndDiagnostic.py","ApplyV6610DiagnosticPipeline.py",
"ApplyV6611UnifiedMusicChat.py","ApplyV670ContextMusicChat.py","ApplyV671DialogFirst.py","ApplyV672DiagnosticSaveFix.py","ApplyV673ActorFix.py",
"ApplyV674DialogAndDiagnosticUX.py","ApplyV675DiagnosticModalAndPreparedState.py","ApplyV300MusicChatCore.py","ApplyV301Corrections.py",
"ApplyV302SlotAndSourceFix.py","ApplyV303Consistency.py","ApplyV304IdeaPanelCleanup.py","ApplyV305MusicalIdeaQuality.py",
"ApplyV306PreserveWorkingIdea.py","ApplyV307CentralCLAB.py","ApplyV308MainCleanup.py","ApplyV309SessionMemory.py","ApplyV330Engine2.py",
"ApplyV331CompleteAILog.py","ApplyV332FreshCompositionContext.py"
]
p63=root/"ApplyV63MainLayout.py"; s63=p63.read_text(encoding="utf-8")
a=s63.find("# Richer labels for the large V6.3 cards."); b=s63.find("p.write_text(s, encoding='utf-8')",a)
if a>=0 and b>=0:
    p63.write_text(s63[:a]+"# Card labels are patched separately.\\n\\n"+s63[b:],encoding="utf-8")
for name in patches: subprocess.run(["python3",name],cwd=root,check=True)

models=root/"Sources/Models.swift"; s=models.read_text(encoding="utf-8"); start=s.find("enum ComposerPrompts {")
if start<0: raise SystemExit("ComposerPrompts not found")
clean=r'''enum ComposerPrompts {
    static let engineBuild = 22

    static let system = """
    Du bist ein eigenständiger Komponist.
    """

    static func conceptPrompt(_ assignment: String) -> String {
        """
        Entwickle zunächst deine eigene musikalische Vorstellung zu diesem Kompositionsauftrag:

        \(assignment)

        In diesem Schritt noch keine technische Ausgabe: kein JSON, MIDI, MusicXML, LilyPond,
        ABC oder Programmcode. Antworte nur mit deiner musikalischen Vorstellung.
        """
    }

    static let technical = """
    TECHNISCHES AUSGABEFORMAT

    Gib die bereits komponierte Musik ausschließlich als valides JSON in dieser Struktur aus:
    {
      "ti": "Titel",
      "bpm": 96,
      "ts": {"n": 4, "d": 4},
      "k": "e minor",
      "sm": "Kurze Zusammenfassung",
      "tr": [{"nm":"Piano","ch":0,"pg":0,"nt":[[0.0,1.0,60,80,1,0.95]],"ct":[],"ev":[],"me":[]}]
    }

    TECHNISCHE BEDEUTUNG
    - nt: [StartBeat, DauerInViertelnoten, MIDIPitch, Velocity, Staff, Gate].
      Staff: 0=Standard, 1=oberes System, 2=unteres System. Gate ist optional; Standard 0.95.
    - ct: [Beat, CC, Wert].
    - me: optionale rohe Nicht-Noten-MIDI-Ereignisse als
      {"b":Beat,"m":"HEX-BYTES","selected":true/false,"muted":true/false}.
      Vorhandene me-Ereignisse einer geladenen Vorlage unverändert erhalten, sofern der Nutzer nicht ihre Änderung verlangt.
    - ev: optionale Notations-/Ausdrucksereignisse als
      {"b":Beat,"t":Typ,"v":Wert,"e":EndBeat,"st":Staff,"p":MIDIPitch,"n":BPM}.
      Nur tatsächlich in der komponierten Musik vorhandene Angaben kodieren.
      Typen: dyn, art, orn, pedal, wedge, tempo, slur, words.
      dyn: pp,p,mp,mf,f,ff,sf,sfz,fp
      art: staccato,tenuto,accent,marcato,fermata
      orn: trill,acciaccatura,appoggiatura
      pedal: start,change,stop
      wedge: crescendo,diminuendo
      Bei semantischen pedal-Ereignissen dasselbe Pedal nicht zusätzlich als CC64 in ct kodieren.

    Die technischen Felder beschreiben die Musik; sie geben keine musikalischen Entscheidungen vor.
    Gib ausschließlich das JSON-Objekt aus.
    """
}
'''
models.write_text(s[:start]+clean,encoding="utf-8")

api=root/"Sources/APIClient.swift"; a=api.read_text(encoding="utf-8")
a=re.sub(r'func begin\(provider: Provider, model: String, effort: Effort,\s*system: String, user: String, wantJSON: Bool\) -> Int \{',
         'func begin(provider: Provider, model: String, effort: Effort, purpose: String,\\n               system: String, user: String, wantJSON: Bool) -> Int {',a, count=1)
a=a.replace('"reasoning": effort.rawValue,\n                "wantJSON": wantJSON,',
            '"reasoning": effort.rawValue,\n                "purpose": purpose,\n                "wantJSON": wantJSON,',1)
a=re.sub(r'func call\(provider: Provider, model: String, key: String, effort: Effort,\s*system: String, user: String, wantJSON: Bool, completion: @escaping Completion\) \{\s*let logID = AICommunicationLog\.shared\.begin\(provider: provider, model: model, effort: effort,\s*system: system, user: user, wantJSON: wantJSON\)',
         'func call(provider: Provider, model: String, key: String, effort: Effort, purpose: String,\\n              system: String, user: String, wantJSON: Bool, completion: @escaping Completion) {\\n        let logID = AICommunicationLog.shared.begin(provider: provider, model: model, effort: effort, purpose: purpose,\\n                                                    system: system, user: user, wantJSON: wantJSON)',a,count=1)
if '"purpose": purpose' not in a or 'purpose: String' not in a:
    raise SystemExit("API purpose logging rewrite failed")
api.write_text(a,encoding="utf-8")

main=root/"Sources/MainViewController.swift"; m=main.read_text(encoding="utf-8")
m=re.sub(r'"interfaceVersion": "[0-9.]+"','"interfaceVersion": "3.4.0"',m)

ws0=m.find("    private func musicChatWorkspaceContext() -> String {"); ws1=m.find("    private func musicChatSourceMaterial(_ slots: [Int]) -> String {",ws0)
if ws0<0 or ws1<0: raise SystemExit("workspace block not found")
workspace=r'''    private func musicChatWorkspaceContext() -> String {
        var slotObjects: [[String: Any]] = []
        for (index, item) in pieceSlots.enumerated() {
            guard let item else { continue }
            slotObjects.append(["slot":index+1,"title":item.title,"concept":item.concept,
                                "provider":item.provider.rawValue,"model":item.model])
        }
        let fullConversation = chatView.string
        let limit = 12000
        let recentConversation = fullConversation.count > limit
            ? "[Älterer Dialog lokal gespeichert; für diesen Aufruf gekürzt.]\\n" + String(fullConversation.suffix(limit))
            : fullConversation
        let object: [String: Any] = [
            "settings":["measures":measuresField.stringValue,"meter":meterField.stringValue,
                        "tempo":tempoField.stringValue,"key":musicalKeyField.stringValue,"ensemble":ensembleField.stringValue],
            "activeSlot":activePieceSlot+1,
            "slotIndex":slotObjects,
            "recentConversation":recentConversation,
            "currentAssignment":promptView.string,
            "currentCompositionIdea":conceptView.string
        ]
        guard JSONSerialization.isValidJSONObject(object),
              let data=try? JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]),
              let text=String(data:data,encoding:.utf8) else { return "{}" }
        return text
    }

'''
m=m[:ws0]+workspace+m[ws1:]

chat0=m.find('@objc private func chatPressed()'); dp0=m.find('        let dialoguePrompt = """',chat0); dp1=m.find('        """',dp0+30)
if dp0<0 or dp1<0: raise SystemExit("dialogue prompt not found")
dp1+=len('        """')
dialogue=r'''        let dialoguePrompt = """
        Du bist der musikalische Gesprächspartner im MusicChat von Composition Lab.
        Dieser Aufruf dient ausschließlich Gespräch und Ideenarbeit; er erzeugt keine Partitur.

        Der ARBEITSRAUM ist Gedächtnis und Orientierung, nicht automatisch musikalisches Ausgangsmaterial.
        Vorhandene Slots oder eine frühere Kompositionsidee werden nur dann zu Material, wenn der aktuelle
        Nutzerwunsch erkennbar darauf Bezug nimmt. sourceSlots nennt ausschließlich solche tatsächlich
        gewünschten Quellen. Bei einem neuen Kompositionsvorhaben entwickelst du die Idee aus dem aktuellen
        Nutzerwunsch und den ausdrücklich gesetzten Rahmenbedingungen.

        Antworte ausschließlich als JSON:
        {
          "reply":"natürliche Dialogantwort",
          "compositionAssignment": null ODER "aktueller Kompositionsauftrag",
          "compositionIdea": null ODER "aktuelle musikalische Vorstellung",
          "sourceSlots":[1,2]
        }

        ARBEITSRAUM:
        \(workspace)

        AKTUELLER NUTZERBEITRAG:
        \(msg)
        """'''
m=m[:dp0]+dialogue+m[dp1:]

old='''            let ideaPrompt = """
            \(ComposerPrompts.conceptPrompt(assignment))

            WICHTIG FÜR COMPOSITION LAB 3.0:
            Formuliere nur einen kurzen musikalischen Gedanken/Impuls in höchstens drei kurzen Sätzen.
            Kein detaillierter Ablauf und kein technischer Bauplan. Noch keine Partitur erzeugen.
            """'''
m=m.replace(old,'            let ideaPrompt = ComposerPrompts.conceptPrompt(assignment)',1)

old='''        let compPrompt = """
        \(ComposerPrompts.technical)

        AUFTRAG:
        \(assignment)

        VERBINDLICHE AKTUELLE KOMPOSITIONSIDEE:
        \(finalIdea)

        Die obige Kompositionsidee kann vom Nutzer manuell bearbeitet worden sein. Verwende genau diese aktuelle Fassung als musikalische Grundlage und ersetze sie nicht durch eine frühere KI-Fassung.

        \(titleAvoidanceInstruction())

        Gib jetzt die fertige JSON-Partitur aus.
        """'''
new='''        let compPrompt = """
        AUFTRAG:
        \(assignment)

        MUSIKALISCHE VORSTELLUNG:
        \(finalIdea)

        \(ComposerPrompts.technical)

        \(titleAvoidanceInstruction())
        """'''
if old not in m: raise SystemExit("main score prompt not found")
m=m.replace(old,new,1)

m=m.replace('''                \(ComposerPrompts.technical)

                AUFTRAG:
                \(assignment)

                DEIN KONZEPT:
                \(concept.text)

                \(self?.titleAvoidanceInstruction() ?? "Vergib der Komposition einen eigenständigen, prägnanten Titel.")

                Gib jetzt die fertige JSON-Partitur aus.''',
'''                AUFTRAG:
                \(assignment)

                MUSIKALISCHE VORSTELLUNG:
                \(concept.text)

                \(ComposerPrompts.technical)

                \(self?.titleAvoidanceInstruction() ?? "Vergib der Komposition einen eigenständigen, prägnanten Titel.")''')
m=m.replace('''                \(ComposerPrompts.technical)

                AUFTRAG:
                \(assignment)

                DEIN KONZEPT:
                \(concept.text)

                \(self.titleAvoidanceInstruction())

                Gib jetzt die fertige JSON-Partitur aus.''',
'''                AUFTRAG:
                \(assignment)

                MUSIKALISCHE VORSTELLUNG:
                \(concept.text)

                \(ComposerPrompts.technical)

                \(self.titleAvoidanceInstruction())''')

positions=[]; p=0
while True:
    p=m.find("APIClient.shared.call(",p)
    if p<0: break
    positions.append(p); p+=20
shift=0
for op in positions:
    p=op+shift
    funcs=list(re.finditer(r'\bfunc\s+([A-Za-z0-9_]+)\s*\(',m[:p]))
    purpose=funcs[-1].group(1) if funcs else "unknown"
    sp=m.find("system:",p)
    if sp<0: raise SystemExit("system argument missing")
    if "purpose:" not in m[p:sp]:
        ins='purpose: "MainViewController.'+purpose+'", '
        m=m[:sp]+ins+m[sp:]; shift+=len(ins)
main.write_text(m,encoding="utf-8")

plist=root/"Info.plist"; p=plist.read_text(encoding="utf-8")
p=re.sub(r'(<key>CFBundleShortVersionString</key><string>)[^<]+(</string>)',r'\g<1>3.4.0\2',p)
p=re.sub(r'(<key>CFBundleVersion</key><string>)[^<]+(</string>)',r'\g<1>3400\2',p)
plist.write_text(p,encoding="utf-8")

build=root/"Build Native App.command"; oldb=build.read_text(encoding="utf-8"); idx=oldb.find("SRC=(Sources/*.swift)")
if idx<0: raise SystemExit("compile section not found")
tail=oldb[idx:]
tail=tail.replace('echo "Baue Composition Lab Native 3.3.3 …"','echo "Baue Composition Lab Native 3.4.0 · Build 3400 · Engine 2.2 …"')
vpos=tail.rfind('echo "Version:')
if vpos>=0:
    end=tail.find("\\n",vpos)
    tail=tail[:vpos]+'echo "Version: 3.4.0 (Build 3400) · Composition Engine 2.2 · Engine Build 22 · Clean Source"'+tail[end:]
cleanbuild='''#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Composition Lab.app"
BUILD=".build-native"

'''+tail
build.write_text(cleanbuild,encoding="utf-8")

(root/"ENGINE_COMMUNICATION.md").write_text("""# Composition Lab – KI-Kommunikation ab V3.4.0

## Grundsatz
Die App entscheidet nichts Musikalisches. Sie transportiert Nutzerauftrag, bewusst gewählten Kontext und technische Ausgabeanforderungen.

## Ablauf
1. Musikalische Vorstellung – freie KI-Antwort auf den Nutzerauftrag; keine Notation/JSON/MIDI.
2. Komposition – KI komponiert eigenständig aus Auftrag und aktueller musikalischer Vorstellung.
3. Technische Realisation – das JSON-Schema beschreibt ausschließlich die Ausgabe.

## Kontext
- Chat-/Projektgedächtnis ist nicht automatisch Kompositionsmaterial.
- Slot-Scores werden nicht pauschal in jeden MusicChat-Aufruf kopiert.
- Vollständige Scores werden nur dort übertragen, wo die Funktion sie tatsächlich benötigt.
- Der an die KI gesendete Gesprächskontext wird begrenzt; der vollständige Chat bleibt lokal erhalten.

## Protokoll
Jeder zentrale API-Aufruf protokolliert Zweck/Funktion, Provider, Modell, Reasoning, System- und User-Prompt, Antwort, Tokens, Zeit und Fehler. API-Schlüssel und Autorisierungsdaten werden nie protokolliert.

## Entwicklungsregel
Keine Build-Zeit-Patches. Sources ist die maßgebliche, direkt kompilierbare Quelle.
""",encoding="utf-8")

if "static let engineBuild = 22" not in models.read_text(encoding="utf-8"): raise SystemExit("engine 22 missing")
if "purpose:" not in api.read_text(encoding="utf-8"): raise SystemExit("purpose log missing")
if "python3 Apply" in build.read_text(encoding="utf-8"): raise SystemExit("patch call remains")
print("V3.4.0 clean-source consolidation completed.")
