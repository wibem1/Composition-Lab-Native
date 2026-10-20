# Desktop-Kernvertrag 4.2

Mac kompiliert dieselben Quellen direkt; Windows startet `composition-lab-core
service` mit einem UTF-8-JSON-Auftrag auf stdin. stdout enthält NDJSON mit
optionalen `event:progress`-Nachrichten und genau einem Endergebnis. Erfolg:
`ok:true`; Domänenfehler: `ok:false,error`, optional `diagnostic`. Ein Domänenfehler
ist kein Prozessabsturz. Schlüssel stehen ausschließlich im stdin-Auftrag und
werden nicht als Kommandozeilenargument oder temporäre Klartextdatei übergeben.

| Operation | Maßgebliche Eingaben | Nutzlast im Endergebnis |
|---|---|---|
| `build-assignment` | `assignment`, optional `chatInput`, `idea`, `parameters`, `source:{name,score}` | `assignment` |
| `compose-source` | `apiKey`, `request:{assignment,provider,model,effort}` | `result` mit Original, Tokenzahlen, Kostenschätzung und gesendetem Auftrag |
| `chat` | gleiche Eingaben, optional `request.mode:dialogue` und `workspace` | `result.text`, im Dialogmodus auch `result.dialogue` |
| `interpret-composition` | `source` | `interpretation.kind`: `score`, `lilypond` oder `unrecognized`; keine KI |
| `prepare-lilypond` | `source` | `source`; sichere lokale Compilerquelle |
| `source-selection` | `rendered`, `editor`, Quellpunkte | `selection:{start,length,error}` in UTF-16 |
| `register-review` | `score` | `issues`, gemeinsamer Korrekturauftrag `instruction` |
| `validate-register-repair` | `before`, `after`, `source` | nur Erfolg oder fachlicher Fehler |
| `lab-route` | `response` | `route:{compose,reply}`; interne Steuerzeichen werden nicht im Dialog gezeigt |
| `lab-prompt` | `kind`, `task`, optional `first`, `second`, `measures`, `tempo`, `ensemble`, `style` | `prompt`; führt keine KI aus |
| `validate-motif` | `score`, `measures` | Erfolg oder fachlicher Fehler |
| `score-revision` | `request:{operation,state?,slots,slot?}` | `revision:{state,slot?,document?}` |
| `midi-info` | Base64-`data` | `initialBPM`; Anfangstempo statt letztem Tempowechsel |
| `playback-midi` | Base64-`data`, `velocityFactor` 0…1, optional `targetBPM` 20…400 | Base64-`data`; Original unverändert |
| `model-catalog-step` | `provider`, optional `state`, `page` | `catalog:{state,request?}` ohne Schlüssel |
| `midi`, `musicxml` | `score`, optional MusicXML-`options` | Base64-`data` |
| `import-midi`, `import-musicxml` | Base64-`data`, `title` | `score` |
| `validate-document`, `validate-workspace`, `validate-backup` | `document` | nur Erfolg oder fachlicher Fehler |
| `recover-score` | `response` | `score`; lokale Formatrettung |
| `translate-existing`, `compose` | expliziter Legacy-Auftrag mit Schlüssel | ältere ausdrücklich angeforderte Übersetzungsabläufe; nicht der Hauptkompositionsweg |
| `version` | optional `title` | `version`, `titleEcho` |

`ScoreRevisionStore` besitzt die Undo-/Redo-Regeln. `slots` enthält je Stück
`identity` und vollständiges `document`, leere Plätze sind null. `push` speichert
nur eine bereits gültige Fassung. Bei `undo/redo` muss die aktuelle Identität
übereinstimmen; ein ersetztes Stück wird nicht überschrieben. Zustand und
Dokument werden zusammen zurückgegeben; UI-Adapter veröffentlichen sie atomisch.

Native Adapter besitzen ausschließlich UI-, Datei-, Prozess-, Geräte- und
Betriebssystem-Crypto-Aufgaben. `CoreRequestHandle.cancel()` beendet den Transport
seines Auftrags. Revisionszähler verwerfen bereits unterwegs befindliche Ergebnisse.
