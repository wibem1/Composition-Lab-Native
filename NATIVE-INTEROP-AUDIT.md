# Native Interoperability Audit

Stand: 8. September 2026
Branch: `native-core-alignment`
Referenz: Composition Lab Native V5.0.11 / Build 83 / Engine Build 14

## Ziel

Abgleich von MusicXML, DAW-Bridges und den optionalen Score-Feldern `ev` und `me` mit dem gemeinsamen Music-Lab-Core-Vertrag.

## 1. Gemeinsames Score-Superset

Native verwendet bereits das gemeinsame Grundschema und erweitert Tracks optional um:

- `ev`: Notations-/Ausdrucksereignisse
- `me`: rohe Nicht-Noten-MIDI-Ereignisse für verlustärmere DAW-Roundtrips

Diese beiden Felder bleiben optional. Anwendungen, die sie nicht interpretieren, sollen sie bei Projekt-Roundtrips möglichst erhalten.

## 2. MusicXML

### Import

`MusicXMLParser.swift` übernimmt derzeit insbesondere:

- Noten
- Stimmen/Backups/Forwards
- Tempo
- Taktart
- Tonart
- Instrumentname
- MIDI-Programm
- Klaviersystem/Staff

Der Parser erzeugt derzeit keine `ev`-Ereignisse aus MusicXML-Ausdrucks- oder Artikulationsangaben.

Importierte MusicXML-Noten werden aktuell mit `gate = 0.95` angelegt. Das ist nicht derselbe Fehler wie beim MIDI-Import: MusicXML liefert eine notierte Dauer und nicht zwingend eine reale Klingdauer. Deshalb wird diese Stelle vorerst nicht automatisch auf `1.0` geändert.

### Export

`MusicXMLBuilder.swift` nutzt `ev` bereits umfangreich, unter anderem für:

- Dynamik
- Text-/Ausdrucksanweisungen
- Pedal
- Crescendo/Diminuendo
- Artikulationen
- Triller/Ornamente
- Bindebögen
- Vorschlagsnoten
- Staff-/Voice-Zuordnung

Damit ist der Export aus dem Score ausdrucksreicher als der aktuelle MusicXML-Import.

### Konsequenz

MusicXML ist im Native-Stand derzeit nicht vollständig roundtrip-symmetrisch: Ein importiertes MusicXML kann Ausdrucksdetails enthalten, die der Parser nicht in `ev` zurückübersetzt und die deshalb bei einem reinen Score-Neuexport verloren gehen können. `originalMusicXMLData` bleibt deshalb für unveränderte Originale wichtig.

## 3. REAPER Bridge

`ReaperBridge.swift` ist bereits gut auf den gemeinsamen Superset-Ansatz ausgerichtet.

Beim Import:

- Noten werden in `nt` übernommen.
- rohe Nicht-Noten-MIDI-Ereignisse aus `midi_events` werden in `me` übernommen.

Beim Export:

- `nt` wird wieder als Noten ausgegeben.
- `me` wird wieder als `midi_events` ausgegeben.
- ein Program Change bei Beat 0 wird ergänzt, falls kein entsprechendes Rohereignis vorhanden ist.

Dadurch kann die REAPER-Bridge auch Daten wie Pitch Bend, Aftertouch, SysEx/Meta-Ereignisse oder REAPER-spezifische CCBZ-Daten erhalten, sofern die Bridge sie liefert.

Die REAPER-Bridge ist deshalb das bevorzugte Vorbild für zukünftige DAW-Bridges.

## 4. Studio Pro Bridge

`StudioProBridge.swift` ist deutlich einfacher.

Beim Import werden im Wesentlichen Noten, Kanal und Programm übernommen. Die erzeugten Tracks enthalten aktuell weder `ev` noch `me`.

Der JSON-Rückweg enthält ebenfalls primär:

- Noten
- Kanal
- Programm
- Tempo
- Taktart

`ct`, `ev` und `me` werden dort nicht als vollständiger Roundtrip-Vertrag transportiert.

Damit ist Studio Pro funktional nutzbar, aber nicht verlustarm im Sinne des gemeinsamen Superset-Core.

## 5. Ableton

Eine eigenständige Ableton-/Max-for-Live-Bridge ist in Native V5.0.11 noch nicht Bestandteil des gesicherten Quellstands.

Für die spätere Ableton-Anbindung soll daher das REAPER-Modell als Architekturvorbild dienen:

- `nt` für Noten
- `ct` für strukturierte Controller, soweit sinnvoll
- `me` für rohe Nicht-Noten-MIDI-Ereignisse und DAW-spezifische Zusatzdaten
- keine neue konkurrierende Score-Repräsentation

## 6. Bewertung

### Bereits kompatibel

- gemeinsames Score-Grundschema
- optionale Felder `ev` und `me`
- MusicXML-Export aus `ev`
- REAPER-Roundtrip mit `me`

### Noch nicht symmetrisch / offen

- MusicXML-Import erzeugt `ev` noch nicht aus Ausdrucks-/Artikulationsdaten
- Studio Pro transportiert `ct/ev/me` nicht vollständig
- Ableton-Bridge fehlt im Native-Referenzstand

## 7. Nächste Schritte

1. MusicXML-Import nicht vorschnell erweitern; zuerst festlegen, welche `ev`-Typen verbindlicher Core sein sollen.
2. REAPER-Bridge als Referenz für zukünftige DAW-Adapter verwenden.
3. Studio-Pro-Bridge nur dann erweitern, wenn der Zielworkflow diese zusätzlichen Daten tatsächlich unterstützt.
4. Ableton/Max-for-Live später direkt auf den gemeinsamen Score-/`me`-Vertrag aufsetzen.
5. Referenzbranch `reference-v5.0.11` unverändert lassen; Änderungen ausschließlich in Entwicklungsbranches.
