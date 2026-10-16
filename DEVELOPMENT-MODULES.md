# Composition Lab – Entwicklungs- und Modulhandbuch

Stand: 16.10.2026 · Entwicklungszweig `v4-cross-platform` · Windows V4.14 + weitere, **noch ungeprüfte** Änderungen

## Zweck und Gültigkeit

Dies ist der zentrale Einstieg für die fortlaufende technische Dokumentation. Bestehende Unterlagen (`V4-ARCHITECTURE.md`, `Windows/V4.1-CODE-AUDIT.md`, die MusicXML-Prüfungen) bleiben erhalten und werden von hier aus ergänzt. Aussagen über den Ist-Zustand sind von Architektur-Zielen ausdrücklich getrennt.

### Verbindliches Entwicklungsprinzip: echte Module statt großer Sammelklassen

Jedes Modul besitzt **eine klar abgegrenzte Aufgabe**, eine dokumentierte öffentliche Schnittstelle und benennbare Ein- und Ausgaben. Module kommunizieren über typisierte Verträge oder validierte JSON-Datentransfers, nicht über beliebig veränderbare globale GUI-Felder. UI, Musikverarbeitung, Persistenz und Anbieterzugriff dürfen sich nicht gegenseitig implementierungsabhängig machen.

Jede neue Funktion und jede größere Änderung dokumentiert:
- **Modulname und Aufgabe**, Quellpfad und verantwortliche Schicht;
- **öffentliche Aufrufe und Eingaben** (Namen, Datentypen, Wertebereiche, Einheiten, optional/pflichtig);
- **Ausgaben** (Ergebnisformat, Fehlerfälle), Seiteneffekte und Datenbesitz;
- **Abhängigkeiten**, Thread-/Async-Verhalten und Abbruch-/Timeout-Semantik;
- **Tests** (Normalfall, ungültige Eingaben, Grenzwerte, Abbruch, Wiederherstellung);
- **Migrations- und Kompatibilitätswirkung**, falls Datenformate geändert werden.

Keine Modultrennung nur zur Kosmetik: `partial MainForm` in mehreren Dateien ist **nicht** automatisch ein unabhängiges Modul. Bestehende Arbeitsabläufe werden nur mit Regressionstests umgebaut; keine blind durchgeführten flächendeckenden Refaktorierungen.

## Modulverzeichnis: überprüfter Ist-Zustand (Windows)

| Bestandteil / Datei | Aktuelle Aufgabe | Relevante Ein- und Ausgaben | Status und Trennungsbedarf |
|---|---|---|---|
| `CoreClient.cs` | Verbindung zum gemeinsamen Swift-Kern über Prozess-stdin/stdout | `RunAsync(JsonObject request, CancellationToken, Action<string>? progress)` → `Task<JsonObject>`; Fehler als Ausnahme/Diagnose | Eigenständige Klasse; JSON-Operationsverträge separat versionieren |
| `LilyPondCompiler.cs` | LilyPond-Quelle vorbereiten, lokal kompilieren, Ergebnis cachen | `Prepare(string source)` → `string`; `CompileAsync(string source, CancellationToken)` → `LilyPondOutput(Midi, Pages, Log, Milliseconds, Cached)` | Eigenständige Klasse; Dateizugriff und Compiler-Prozess sind Seiteneffekte |
| `MidiPlayer.cs` | Windows-MIDI-Wiedergabe | MIDI-Bytes/Transportbefehle → hörbare Ausgabe, Playerzustand | Player-Modul; GUI-Kopplung im aufrufenden Code überprüfen |
| `SecretStore.cs` | Gespeicherte Provider-Schlüssel | Schlüssel-Dictionary → verschlüsselte Persistenz / Rücklesung | Sicherheitsadapter; Geheimnisse nie in Diagnosen oder Projektdateien |
| `ModelCatalog.cs`, `ModelCatalogUI.cs` | Dynamische Modelllisten und deren GUI-Anbindung | Provider-Modellmetadaten → auswählbare Modelle; UI-Ereignisse | Katalog/Anzeige teilweise getrennt; Preis- und Fähigkeitsdaten als eventuell unvollständig behandeln |
| `SlotWorkspace.cs` | Dokument-Slots, Wechsel, Import und Anzeigeaufbau | Slotindex / Dokument → `documents[]`, Noten-/Player-/Editorzustand | **Teil von `MainForm`**, keine isolierte Slot-Engine; Risiko überlappender Async-Ladevorgänge |
| `ProjectPersistence.cs` | Projektserialisierung und Projektladen | `.clabproject` und GUI-/Slot-Zustand → validiertes Workspace-Dokument / wiederhergestellter Zustand | **Teil von `MainForm`**; Trennung von Dateivertrag, Repository und GUI erforderlich |
| `CompositionWorkflow.cs` | Benutzerauftrag, KI-Anfrage, Konvertierung und Übernahme | Auftrags-/Provider-/Modelleinstellungen → KI-Antwort, Diagnose, Slotdokument | **Teil von `MainForm`**; Anbieter-/Geschäftslogik entkoppeln |
| `DirectLilyPond.cs` | Editieren/Übernehmen von LilyPond und SVG-Notenansicht | Quelltext + Score-Dokument → MIDI/SVG, Editorpositionsauswahl | **Teil von `MainForm`**; Quelltext-Zuordnung und UI separat testen |
| `RegisterReview.cs` | Prüfen auffälliger Oktavlagen und optionale Korrektur | Score/LilyPond → Prüfbefund, ggf. Kandidat | **Teil von `MainForm`**; musikalische Entscheidung nicht aus bloßer Tonhöhen-Grenze ableiten |
| `ScoreUndo.cs` | Partiturrevisionen | Score-Zustand → Undo-/Redo-Verlauf | **Teil von `MainForm`**; Transaktionsgrenzen dokumentieren |
| `DiagnosticRecovery.cs` | Diagnosen und Wiederherstellung | Diagnose-/Antwort-JSON → rekonstruierbare Daten oder Fehler | **Teil von `MainForm`**; Formatvalidierung vom Dialog trennen |
| `MusicFileIO.cs` | Dateiformatbezogene Import-/Exportaktionen | MIDI, MusicXML, LilyPond, Projektdateien → gespeicherte/geladene Artefakte | **Teil von `MainForm`**; Konverter von Datei-Dialogen trennen |
| `MainForm.cs`, `MacGui.cs` | Windows-Fenster, UI-Events und übergreifender Zustand | Benutzerereignisse → GUI, Dokumentoperationen | **Noch große, gekoppelte `MainForm`-Teile**, kein erfülltes Modulziel |
| `StudioTheme.cs` | UI-Designkomponenten | Anzeigeparameter → Controls/Stil | Darstellungsschicht |

### Gemeinsamer Kern und Plattformen

- `Shared/CompositionCore/`: musikalische Daten und zentrale Konvertierungs-/Kompositionsdienste. Der dokumentierte Eintritt ist `CoreServices` mit JSON/Data-Vertrag; maßgeblich sind Quellcode und Tests, nicht allein historische Architekturbeschreibungen.
- `Shared/Interface/`: Schnittstellenquellen; konkrete Aufrufverträge müssen bei Änderungen hier oder am Service mitgepflegt werden.
- `Sources/`: native macOS-Adapter für Fenster, MIDI-Ausgabe, Schlüssel und DAW-Anbindung. Plattformbedingte Unterschiede gehören in Adapter, nicht als Bedingungen in den musikalischen Kern.

## Zielmodule für die schrittweise Entkopplung (noch **nicht** implementiert)

1. **DocumentStore**: `Get(slot:int) -> Document?`, `Replace(slot:int, document:Document) -> Result`; besitzt Slots und Revision. Keine UI-Abhängigkeit. 
2. **WorkspacePersistence**: `Load(path:string) -> Workspace`, `Save(path:string, workspace:Workspace) -> Result`; garantiert Validierung und atomisches Schreiben.
3. **CompositionService**: `Compose(assignment:string, provider:Provider, model:string, cancellation:CancellationToken) -> CompositionResult`; keine Formularfelder als Eingaben.
4. **ScoreRenderService**: `Render(source:LilyPondSource, cancellation) -> RenderedScore`; enthält SVG/MIDI plus stabile `sourceRevision`.
5. **ScoreSelectionMapper**: `Map(renderRevision, noteSourceLocations[], editorRevision) -> SourceRanges | StaleRevisionError`; darf **niemals** stillschweigend zu falschem Quelltext springen.
6. **PlaybackService**: `Load(midi:byte[]) -> Result`, `Play/Pause/Stop/Seek`; eigenes Lebenszyklusmanagement.
7. **WorkspaceController**: koordiniert UI-Ereignisse, laufende Anfragen, Versionszähler und Status, delegiert Arbeit; besitzt keine Notensatz- oder Dateiformatlogik.

*Die Signaturen der Zielmodule beschreiben Architekturverträge, keine bereits vorhandenen APIs.* Details werden erst mit der jeweiligen Implementierung verbindlich.

## Integrationsregeln

- **Ein Eigentümer je Zustand:** Ein Score/Slot besitzt eine eindeutig identifizierbare Revision. Laufende Ergebnisse dürfen nur bei identischer Revision und gleichem Slot übernommen werden.
- **Transaktionale Änderungen:** Erst vollständig validieren, dann publizieren. Fehler erhalten die letzte gültige gespeicherte Fassung; UI zeigt klar einen Ladefehler statt fremde Noten.
- **Notation und Editor:** SVG-Klickpositionen gelten ausschließlich für die exakt gerenderte Quellrevision. Mehrfachauswahl und Oktavbearbeitung verändern nicht stillschweigend unmarkierte Stimmen.
- **Benutzerauftrag und Musikquelle:** getrennte Felder; Änderungen an LilyPond überschreiben niemals den eigentlichen Kompositionsauftrag.
- **Kompatibilität:** `.clab`, `.clabproject`, MIDI, MusicXML und LilyPond benötigen Referenz-Fixtures vor Formatänderungen.
- **Tests vor Freigabe:** Modul-Unit-Tests, Schnittstellen-/Kontrakttests, Regressionen und Windows-GUI-Test; Grün bedeutet *bestandenes Testset*, nicht fehlerfreie Software.

## Entwicklungsprotokoll

| Datum | Stand | Befund / Entscheidung | Nachweis |
|---|---|---|---|
| 16.10.2026 | V4.14 veröffentlicht | Slotstatus, LilyPond-Auswahl und Trennung des Eingabeauftrags überarbeitet; Benutzer meldete vorher unbedienbare V4.13-Notenauswahl | GitHub Actions Lauf `38893705554` |
| 16.10.2026 | nach V4.14, **nicht freigegeben** | Veraltete Notenanzeige bei Ladefehler zurücksetzen; Editor-Auswahl bei nicht übereinstimmender Quellfassung verweigern | Commits `61621449`, `f0ca8fb9`; erneute Prüfungen ausstehend |
| 16.10.2026 | Dokumentationsentscheidung | Modulare Architektur, dokumentierte Ein-/Ausgaben und fortlaufendes Protokoll verbindlich festgelegt | Dieses Dokument |

### Noch bekannte, nicht als erledigt deklarierte Punkte

- GUI- und Slot-Zustand teils über `partial MainForm` gekoppelt; weiterer Umbau nur schrittweise und regressionsgesichert.
- Auswahl per SVG-Link deckt nicht jede gewünschte musikalische Passage ab; Quelltextbereiche sind keine musikalisch semantischen Bereiche.
- Globale Chat-Historie nicht eindeutig einem Slot zugeordnet.
- Gleichzeitige Slot-/Ladevorgänge, Fehler-Rollback und Source-Revisionen benötigen gezielte Härtung und Tests.
- Mac- und Windows-Oberflächen verwenden unterschiedliche Plattformadapter; Parität ist nicht allein durch gemeinsamen Kern bewiesen.

**Pflegepflicht:** Bei jeder relevanten Codeänderung Modulzeile, Vertrag, offenen Punkt, Test und Entwicklungsprotokoll aktualisieren. Keine Freigabe allein aufgrund einer Dokumentationsänderung.


## Verbindlicher Änderungsprozess (Beschluss vom 16.10.2026)

**Gilt nach der grundlegenden Architekturstabilisierung für jede funktionale Codeänderung.** Die folgenden Schritte sind ein Freigabegate, keine unverbindliche Checkliste:

1. **Modulzuordnung:** Bestehendes zuständiges Modul bestimmen oder neues Modul samt Verantwortung und Vertragsgrenzen entwerfen.
2. **Wirkungsanalyse:** Gesamten betroffenen Datenfluss, Aufrufer und Aufgerufene, Slot-/Dokumentrevisionen, Persistenz, UI-Zustand, Parallelität und Fehlerwege erfassen. Schnittstellenänderungen explizit kennzeichnen.
3. **Vorab-Simulation:** Mit Fixtures, Mocks, Zustandsmodellen und möglichst ausführbaren Vertrags-/Szenariotests Normal-, Grenz-, Abbruch-, Parallelitäts- und Fehlersituationen durchspielen. Rein gedankliche Simulationen sind als solche zu kennzeichnen; sie ersetzen keine Tests.
4. **Konflikte vor Implementierung klären:** Gefundene Risiken konkret beheben oder den Entwurf ändern. Erkennbare offene Probleme werden nicht stillschweigend in eine Freigabe übernommen.
5. **Gezielt implementieren:** Nur erforderliche Module ändern; zusätzliche Abhängigkeiten dokumentieren und insbesondere zyklische Abhängigkeiten vermeiden.
6. **Verifizieren:** Unit-, Schnittstellen-, Integrations-, Regressionstests sowie relevante Plattform-/GUI-Prüfungen ausführen. Testnachweise und verbleibende Einschränkungen festhalten.
7. **Dokumentieren:** Modulverzeichnis, Ein- und Ausgabeparameter, Datenfluss- und Abhängigkeitsübersicht, Entscheidungsbegründung sowie Entwicklungsprotokoll auf den neuen Stand bringen.
8. **Versionieren und freigeben:** Erst nach erfolgreichen Prüfungen eine eindeutig neue Version erstellen, Diagnose/Buildnachweis archivieren und freigeben. Keine als erfolgreich dargestellten ungetesteten Pakete.

### Änderungsschein / Pflichtfelder je Codeänderung

- **Anlass, gewünschtes Verhalten und Nicht-Ziele**
- **Verantwortliches Modul** (oder neues Modul mit Begründung)
- **Betroffene Module und Abhängigkeitsgraph**; Input-/Output-Verträge vor/nach der Änderung
- **Datenfluss vom Benutzerereignis bis zum Resultat**; Persistenz und Seiteneffekte
- **Simulationsszenarien** einschließlich Fehler- und Parallelfällen; erwartete Ergebnisse
- **Befunde der Vorprüfung und Lösung**
- **Implementierte Commits, Testfälle, CI-Lauf / Ergebnis**
- **Dokumentationsänderung, neue Version, Freigabestatus**

**Grundsatz:** Erst Architektur und Datenfluss verstehen, dann simulieren und Probleme klären, danach implementieren, testen, dokumentieren und veröffentlichen. Der musikalische Bestand bleibt durch Referenzstücke und Format-Fixtures geschützt.
