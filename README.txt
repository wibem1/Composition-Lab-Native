Composition Lab Native V4.47

Neu: REAPER-Rückkanal V0.3. Die jeweils aktuelle Partitur wird automatisch als strukturierte Übergabedatei für das REAPER-Import-Script bereitgestellt.

Composition Lab Native V4.45.1

V4.45.1: REAPER-Bridge V0.2. Composition Lab beobachtet die vom ReaScript erzeugte Übergabedatei und übernimmt einen neu gesendeten MIDI-Clip automatisch als Vorlage. Die App wird dabei in den Vordergrund geholt. Basis: stabiler Stand V4.44.


Korrektur: Buildfehler im Vergleichslabor behoben (ungueltige Drop-Closure in Ergebnis- und Dialogkarte entfernt). Die Drop-Funktion bleibt auf den vorhandenen Quellenkarten A/B erhalten.

V4.42: Drag & Drop ohne zusätzliche sichtbare Flächen. Vorhandene Bereiche dienen als Ziele: Kompositionsseite, aktuelle Vorlage/Player im Experimentallabor sowie die beiden vorhandenen Quellenkarten A/B im Vergleichslabor. MIDI und MusicXML werden unterstützt. Export-Drag bleibt erhalten.

V4.40: Drag & Drop auf der Kompositionsseite akzeptiert MIDI (.mid/.midi) und MusicXML (.musicxml/.xml). MusicXML wird direkt in das interne Scoreformat übernommen. Der Datei-Auswahldialog akzeptiert dieselben Formate.

Vergleichslabor neu gestaltet:
- drei gleichwertige Karten: Quelle A, Quelle B, Ergebnis
- A und B besitzen jeweils eine eigene dauerhaft aktive MIDI-Drop-Fläche
- Dateiname wird nach Drag & Drop sichtbar angezeigt
- Ergebnis erhält eigenen Player und „An Komposition übergeben“
- „Neue Fassung erzeugen“ heißt jetzt „Aus A und B komponieren“
- KI-Dialog liegt als gemeinsamer Arbeitsbereich unter den drei Karten

Kompositionskern Engine Build 14 unverändert.

V4.38: Vergleichslabor kompakter; echte Innenabstände zu allen Kartenrändern; kleinere A/B-, Dialog- und Ergebnisfelder.

V4.38: Chat-Eingabefeld im Vergleichslabor als korrekt dimensionierte, editierbare NSTextView in NSScrollView repariert.

V4.38: Alle MIDI-Player zeigen das Wiedergabetempo an und erlauben eine Änderung zwischen 20 und 300 BPM. Die Änderung betrifft nur die Wiedergabe, nicht die gespeicherte Partitur.

V4.47: Studio-Pro-Eingangsbridge. Composition Lab beobachtet zusätzlich die Datei CompositionLab_StudioPro_Bridge.json im Benutzer-Dokumente-Bereich und übernimmt daraus ausgewählte MIDI-Clips aus Fender Studio Pro / Studio One.


V4.48: Schreibt die jeweils aktuelle Composition-Lab-Komposition als CompositionLab_Return.mid in den bereits ermittelten Studio-Pro-$USERCONTENT-Ordner. Damit kann Studio Pro sie per Rückhol-Befehl direkt importieren.


V4.49 – Studio-Pro-Rückgabe, strukturierter Test
- schreibt zusätzlich CompositionLab_Return.json neben die Studio-Pro-Brückendatei
- enthält Titel, Tempo, Taktart, Spuren und sämtliche Noten des aktuellen Scores
- vermeidet den abgestürzten Studio-Pro-Dateiimport vollständig
- aktualisiert die Rückgabedatei auch nach einer Überarbeitung im Konzeptdialog


V4.50 – Studio-Pro-Rückgabeformat korrigiert
- CompositionLab_Return.json verwendet jetzt ein bewusst einfaches Objektformat
- Noten werden als Objekte mit start, duration, pitch, velocity, channel geschrieben
- keine verschachtelten nt-Zahlenarrays mehr für den Studio-Pro-Rückweg
- Titel, Tempo, Taktart und note_count werden separat mitgegeben


V4.51 – Studio-Pro-Mehrspur-Hinweg
- Studio Pro → Composition Lab versteht jetzt das Mehrspurformat der Bridge V0.5.6+.
- Mehrere in Studio Pro ausgewählte MIDI-Parts bleiben in Composition Lab getrennte Tracks.
- Trackname, Kanal und Program-Feld werden pro Track übernommen.
- Gemeinsame zeitliche Lage der ausgewählten Parts bleibt erhalten.
- Das alte Einspurformat bleibt vollständig kompatibel.
- Engine Build 14 unverändert.

V4.52 – REAPER Voll-MIDI-Brücke
- Mehrere ausgewählte REAPER-MIDI-Clips werden als getrennte Tracks übernommen.
- Nicht-Noten-MIDI-Ereignisse werden in `me` erhalten: alle CC, Program Change,
  Pitch Bend, Channel Pressure, Poly Aftertouch sowie rohe SysEx/Meta-/CCBZ-Daten.
- Rückgabe an REAPER erhält diese Ereignisse wieder pro Track.
- Engine Build 14 unverändert.

V4.53 – Verlauf per Doppelklick vollständig laden
- Doppelklick auf einen Verlaufseintrag lädt die gespeicherte Komposition vollständig
  in den Player und in die Kompositions-/Editorfelder.
- Übernommen werden Titel/Name, Tempo, Taktart, Tonart, Besetzung und rekonstruierte Taktzahl.
- Der Titel bleibt exakt der gespeicherte Titel und wird auch für Export/Player verwendet.
- Die geladenen Editorwerte werden als aktueller Arbeitsstand gespeichert.
- Engine Build 14 unverändert.

V4.53.1 – Kompilierkorrektur
- ReaperBridge.swift: `ev.b` → `ev.beat`.
- Keine Funktionsänderung gegenüber V4.53.
- Engine Build 14 unverändert.

V4.53.2 – Dateititel beim Import
- Beim Laden einer MIDI-Datei wird der Dateiname ohne .mid/.midi als sichtbarer Titel gesetzt.
- Dadurch erscheint der Titel sofort in der Anzeige und im Verlauf.
- Dasselbe Verhalten gilt konsistent auch für MusicXML-Dateien.
- Doppelklick-Laden aus dem Verlauf und REAPER-Voll-MIDI bleiben unverändert.
- Engine Build 14 unverändert.

V4.6 – Getrennte Verläufe der drei Arbeitsbereiche
- Composer, Experimentallabor und Vergleichslabor besitzen jetzt getrennte sichtbare Verläufe.
- Neue Composer-Einträge werden als Composer-Verlauf gespeichert.
- Im Experimentallabor erzeugte Vorlagen erscheinen nur im Experiment-Verlauf.
- Im Vergleichslabor erzeugte neue Fassungen erscheinen nur im Vergleichs-Verlauf.
- Das Vergleichslabor kann für Quelle A/B weiterhin auf den gesamten gespeicherten Materialpool zugreifen.
- Alte Verlaufseinträge ohne Bereichskennzeichnung bleiben kompatibel und erscheinen im Composer.
- Maximal 15 Einträge je Arbeitsbereich statt 15 Einträge insgesamt.
- „Verlauf löschen“ im Composer löscht nur den Composer-Verlauf.
- Doppelklick-Funktion, Dateititel und REAPER-Voll-MIDI bleiben erhalten.
- Engine Build 14 unverändert.

V4.7 – Eigenes Composition-Lab-Dateiformat (.clab)
- .clab speichert einen vollständigen musikalischen Arbeitsstand unabhängig vom Verlauf.
- Enthalten: Partitur, Titel, Kompositionsidee, KI/Modell, Takte, Taktart, Tempo,
  Tonart, Besetzung, Kompositionsauftrag, Herkunft und optionale Kosten-/Tokenangaben.
- Der Verlauf ist nicht Bestandteil der .clab-Datei.
- Fremde MIDI-/MusicXML-Dateien können weiterhin geladen werden und haben zunächst keine Kompositionsidee.
- Nach Bearbeitung können auch solche Dateien als .clab mit vollständigem Kontext gesichert werden.
- Neue Schaltflächen „CLAB sichern …“ und „CLAB öffnen …“.
- Alte .clabproject-Dateien bleiben lesbar.
- Engine Build 14 unverändert.

V4.7.1 – MIDI- und MusicXML-Daten direkt in .clab
- Eine .clab-Datei enthält jetzt zusätzlich zur internen Composition-Lab-Partitur
  auch eine vollständige MIDI-Darstellung und eine vollständige MusicXML-Darstellung
  des aktuellen Werkstands.
- Wurde ursprünglich eine MusicXML-Datei importiert, werden zusätzlich deren
  unveränderte Originaldaten in der .clab-Datei aufbewahrt.
- Damit enthält CLAB drei musikalische Ebenen: interne Partitur, MIDI und MusicXML.
- Die interne Partitur bleibt die maßgebliche Arbeitsstruktur von Composition Lab.
- Die eingebetteten Binärdaten werden im offenen JSON-basierten CLAB-Format Base64-kodiert.
- Alte .clab-Dateien aus V4.7 bleiben lesbar, weil die neuen Felder optional sind.
- Engine Build 14 unverändert.

V4.7.2 – MusicXML-Rhythmik und Verlauf korrigiert
- MusicXML-Export quantisiert Start- und Endzeiten vor der Ausgabe exakt auf divisions-Ticks.
- Gleichzeitig klingende, sich überlappende Noten werden jetzt auf echte MusicXML-Stimmen verteilt.
- Akkorde bleiben Akkorde, sofern Einsatz und Dauer übereinstimmen.
- Mehrere Stimmen werden mit <backup> taktgenau geschrieben; dadurch können gehaltene Noten
  und später einsetzende Noten denselben Takt nicht mehr rechnerisch überfüllen.
- Vorschlagnoten verbrauchen in der MusicXML-Zeitachse weiterhin keine Dauer.
- MIDI- und MusicXML-Importe erzeugen keinen neuen Composer-Verlaufseintrag mehr.
  Erst ein tatsächlich in Composition Lab erzeugter/bearbeiteter KI-Arbeitsstand kommt in den Verlauf.
- CLAB-Erweiterungen aus V4.7.1 bleiben erhalten.
- Engine Build 14 unverändert.

V4.7.3 – Grace Notes / Verlauf
- Acciaccatura und Appoggiatura werden im MusicXML-Export als echte Grace Notes ohne
  metrische Dauer geschrieben.
- Die sehr kurze MIDI-Dauer einer Vorschlagsnote erzeugt keinen eigenen 16tel/32stel/
  64stel-Notenwert und keine künstliche Ausgleichspause mehr.
- Grace Notes erhalten keine normalen Haltebögen aus der MIDI-Fragmentierung.
- Die in V4.7.2 eingeführte Regel bleibt bestehen: bloß geladene MIDI- und MusicXML-Dateien
  erzeugen keinen neuen Composer-Verlaufseintrag.
- Vorhandene alte Verlaufseinträge werden aus Sicherheitsgründen nicht automatisch gelöscht.
- Engine Build 14 unverändert.

V4.7.4 – Score ist die maßgebliche Komposition
- MusicXML wird bei jedem Speichern und Ziehen frisch aus dem aktuellen internen Score erzeugt.
- In CLAB eingebettete ältere MusicXML-Snapshots werden niemals als Exportquelle benutzt.
- Neu gespeicherte CLAB-Dateien fixieren deshalb keine von Composition Lab erzeugte
  MusicXML- oder MIDI-Austauschdarstellung mehr; maßgeblich ist der interne Score.
- Die optionalen Legacy-Felder midiData/musicXMLData bleiben nur erhalten, damit ältere
  CLAB-Dateien aus V4.7.1–V4.7.3 weiterhin gelesen werden können.
- Eine tatsächlich von außen importierte MusicXML-Datei wird weiterhin unverändert als
  OriginalMusicXMLData bewahrt.
- Dadurch profitieren auch ältere CLAB-Kompositionen bei einem neuen MusicXML-Export
  von späteren Verbesserungen des MusicXMLBuilders.
- Grace-Note-Korrektur aus V4.7.3 und Verlaufskorrektur aus V4.7.2 bleiben erhalten.
- Engine Build 14 unverändert.

V4.7.5 – Vorschlagsnote an folgende Hauptnote binden
- Grace Notes unmittelbar vor einer Taktgrenze werden für MusicXML notatorisch
  an die Hauptnote am Beginn des folgenden Taktes verschoben.
- Der MIDI-/Score-Zeitpunkt bleibt unverändert; nur die Notensatzposition ändert sich.
- sourceStart bewahrt die ursprüngliche Position für die sichere Zuordnung des Ornament-Events.
- Am gleichen Taktschlag werden Grace Notes vor der Hauptnote ausgegeben.
- Ziel: keine isolierte Vorschlagsnote und keine künstliche Restpause am Ende des Vortakts.
- Engine Build 14 unverändert.

V4.7.6 – Grafische Form der Vorschlagsnote
- Grace Notes bleiben metrisch dauerlos (<grace>, keine <duration>).
- Sie erhalten nun ausdrücklich <type>eighth</type>, damit der Notensatz sie als
  kleine Achtel-Vorschlagsnote darstellt.
- Acciaccatura behält <grace slash="yes"/>.
- Die notatorische Bindung an die folgende Hauptnote aus V4.7.5 bleibt erhalten.
- Score und MIDI-Timing bleiben unverändert.
- Engine Build 14 unverändert.

V4.7.7 – Verlauf: keine Duplikate beim Laden
- REAPER- und Studio-Pro-Übernahmen laden den Player, erzeugen aber keinen Verlaufseintrag.
- Das Öffnen einer bestehenden CLAB-Datei erzeugt ebenfalls keinen neuen Verlaufseintrag.
- MIDI- und MusicXML-Dateiimporte bleiben wie bisher verlaufsneutral.
- Zusätzliche Sicherung: Selbst bei Vorgängen, die grundsätzlich in den Verlauf schreiben,
  wird ein vollständig identischer Score mit identischem Impuls, Provider und Modell nicht
  ein zweites Mal eingetragen.
- Bereits vorhandene alte Duplikate werden nicht automatisch gelöscht.
- Engine Build 14 unverändert.

V4.7.8 – Alte DAW-Bridge-Dateien beim Start ignorieren
- Beim Programmstart werden vorhandene REAPER- und Studio-Pro-Bridge-Dateien nur als
  bereits vorhandener Altbestand registriert.
- Sie werden nicht mehr automatisch in den Player geladen.
- Erst wenn REAPER oder Studio Pro die jeweilige Übergabedatei danach neu schreibt,
  übernimmt Composition Lab das Stück.
- Dadurch kann eine alte REAPER-Datei nicht mehr beim Start eine inzwischen andere
  aktuelle Komposition überschreiben.
- Verlaufskorrekturen aus V4.7.7 bleiben erhalten.
- Engine Build 14 unverändert.

V4.7.9 – Letzten Player-Stand über Neustart erhalten
- Composition Lab speichert jetzt unabhängig vom Verlauf den aktuell im Player geladenen Score.
- Gespeichert werden außerdem Impuls, Provider/Modell, Kosten-/Tokenwerte und eine ggf.
  zugehörige importierte Vorlage.
- Beim nächsten Programmstart wird genau dieser letzte Player-Stand wiederhergestellt.
- REAPER-/Studio-Pro-Altdateien überschreiben ihn beim Start weiterhin nicht.
- Das Wiederherstellen erzeugt keinen Verlaufseintrag.
- Engine Build 14 unverändert.

V4.8.0 – MusicXML: MIDI-Spielzeit und Notationsdauer getrennt
- MusicXML rekonstruiert jetzt saubere grafische Notenwerte aus den Spielzeiten.
- Kleine Restlücken vor dem nächsten Einsatz werden bei klaren rhythmischen Abständen
  geschlossen (z.B. 3.8 -> 4, 0.9 -> 1, 0.35 -> 0.5), ohne Score oder MIDI zu verändern.
- Expressive Zwischenwerte werden auf den nächstliegenden üblichen Notenwert quantisiert
  (z.B. 1.2 -> 1, 1.65 -> 1.5).
- Doppelt punktierte/ungebräuchliche Restfragmente werden vermieden; Pausen werden in
  reguläre darstellbare Werte zerlegt.
- Zusätzliche gebräuchliche punktierte Werte (0.375, 0.1875) werden erkannt.
- Vorschlagsnoten-Korrekturen aus V4.7.5/V4.7.6 bleiben erhalten.
- Engine Build 14 unverändert.

V4.8.1 – MusicXML: Einsatzzeiten quantisiert und Taktüberlauf behoben
- Analyse der tatsächlich von V4.8.0 erzeugten MusicXML-Datei zeigte zwei konkrete Ursachen:
  ungewöhnliche Einsatzpositionen blieben unquantisiert und Restzerlegung konnte um wenige
  Ticks über das Taktende hinauslaufen.
- MusicXML-Einsatzzeiten werden jetzt auf ein lesbares 16tel-Raster (0.25 Beat) quantisiert.
- MIDI und interner Score bleiben unverändert.
- Pausenzerlegung arbeitet tickgenau und darf den Takt nicht mehr verlängern.
- Dauerquantisierung aus V4.8.0 bleibt erhalten.
- Engine Build 14 unverändert.

V4.8.2 – MusicXML als lesbare Partiturinterpretation
- Kurze MIDI-Spielzeiten werden nicht mehr automatisch als ebenso kurze Notenwerte
  mit anschließender technischer Pause notiert.
- Liegt der nächste Einsatz auf einem klaren rhythmischen Raster und füllt die klingende
  Note mindestens ungefähr 45 % des Intervalls, wird der notierte Wert bis zum nächsten
  Einsatz geführt (bei höchstens 0.75 Beat Restlücke).
- Beispiel: Start 0.5, MIDI-Dauer 0.5, nächster Einsatz 1.5 -> notierte Viertelnote
  statt Achtelnote + Achtelpause.
- Größere echte Zwischenräume bleiben als Pausen erhalten.
- MIDI und interner Score bleiben unverändert.
- Quantisierung und tickgenaue Taktberechnung aus V4.8.1 bleiben erhalten.
- Engine Build 14 unverändert.

V4.8.3 – MusicXML: Mini-Pausen an Taktgrenzen beseitigt
- Analyse der V4.8.2-MusicXML-Datei zeigte in Takt 3 eine 160-Tick-Note
  (1/3 Beat) gefolgt von 60 + 20 Tick Rest. Diese künstliche Mini-Pause
  entstand durch die generische Triplet-Quantisierung.
- 1/3- und 2/3-Beat-Werte werden nicht mehr automatisch als Standardwerte verwendet.
- Die nächste Taktgrenze gilt nun zusätzlich als natürlicher Notationsanker.
- Beispiel: Start 11.5, MIDI-Dauer ca. 0.35, Taktende 12.0 -> notierte Achtelnote
  bis zur Taktgrenze, keine 1/3-Beat-Note plus Mini-Pausen.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.8.4 – MusicXML: zusammengesetzte Notenwerte spielgerecht binden
- Die V4.8.3-MusicXML-Datei enthielt noch einzelne typ-lose Dauern von 2.5 und 3.5 Beats.
- Solche Dauern werden jetzt in gebräuchliche, gebundene Notenwerte zerlegt.
- Beginnt eine Note zwischen Viertelschlägen, wird zuerst bis zur nächsten Viertelgrenze
  geteilt; danach folgen normale größere Werte.
- Beispiele:
  * Start 1.5, Dauer 2.5 -> Achtel + Halbe (gebunden)
  * Start 0.5, Dauer 3.5 -> Achtel + punktierte Halbe (gebunden)
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.8.5 – MusicXML: sinnlose 16tel-Auftaktpausen vermeiden
- In der geprüften Partitur lag zu Beginn von Takt 2 eine 16tel-Pause (120 Ticks),
  weil der erste Oberstimmen-Einsatz bei Beat 4.25 statt direkt auf Beat 4 lag.
- Für die Partitur wird der erste Einsatz eines Systems nun auf die Taktgrenze gezogen,
  wenn er höchstens 0.25 Beat danach liegt.
- Dadurch verschwinden technische 16tel-Auftaktpausen, die für einen Pianisten keine
  musikalische Funktion haben.
- Echte größere Pausen bleiben erhalten.
- MIDI und interner Score bleiben unverändert.
- Die gebundenen, spielgerechten Notenwerte aus V4.8.4 bleiben erhalten.
- Engine Build 14 unverändert.

V4.9.0 – Vierte Seite „Notensatz“
- Neuer vierter Arbeitsbereich für die MusicXML-Darstellungsquantisierung.
- MIDI und interner Score bleiben unverändert; nur die MusicXML-Darstellung wird beeinflusst.
- Einstellbar:
  * Einsatz-/Positionsquantisierung: Aus, Viertel, Achtel, 16tel, 32tel
  * kurze Pausen: alle zeigen / bis 32tel / bis 16tel / bis Achtel glätten
  * Notenlängen glätten: Aus, Leicht, Mittel, Stark
  * Mini-Pausen am Taktanfang: Aus / bis 32tel / bis 16tel / bis Achtel
  * zusammengesetzte Notenwerte an Zählzeiten teilen und binden
- Presets: „Klavier – lesbar“, „MIDI-nah“, „Benutzerdefiniert“.
- Die Einstellungen werden gespeichert und gelten auch für den normalen MusicXML-Speicher-/Drag-Export.
- Engine Build 14 unverändert.

V4.9.1 – MusicXML-Export ausschließlich im Notensatz
- MusicXML-Import bleibt auf der Composer-Seite erhalten.
- MusicXML-Export wurde vollständig aus der Composer-Seite entfernt.
- Export befindet sich nur noch auf der vierten Seite „Notensatz“.
- Die Notensatz-Seite wurde optisch an die übrigen Arbeitsbereiche angepasst:
  linke Parameter-Spalte, rechte Ergebnis-/Export-Spalte, gleiche Abstände,
  Überschriften, Separatoren und Bedienelemente wie im Composer.
- Auf der rechten Seite wird immer die aktuell im Composer geladene Komposition angezeigt.
- MusicXML kann dort gespeichert oder direkt herausgezogen werden.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.2 – Eigenes NotationProfile als Grundlage für die Notenvorschau
- Die Darstellungsquantisierung ist jetzt in einem eigenen Codable-NotationProfile gekapselt.
- Das Profil enthält Preset und sämtliche MusicXML-Darstellungsparameter.
- MusicXMLBuilder liest ausschließlich die Optionen aus diesem Profil; MIDI und interner Score bleiben getrennt.
- Profile: „Klavier – lesbar“, „MIDI-nah“ und „Benutzerdefiniert“.
- Das zuletzt verwendete Profil wird über Storage dauerhaft gespeichert und beim Start wiederhergestellt.
- Alte V4.9.0/V4.9.1-Einstellungen werden einmalig in das neue Profil migriert.
- Damit ist die technische Grundlage geschaffen, dass eine spätere Notenvorschau exakt dasselbe Profil verwendet wie der Export.
- MusicXML-Export bleibt ausschließlich auf der vierten Seite „Notensatz“; Import bleibt im Composer.
- Engine Build 14 unverändert.

V4.9.3 – Interne Notenbildvorschau
- Die vierte Seite „Notensatz“ enthält jetzt rechts eine große, schnelle Partiturvorschau.
- Die Vorschau wird direkt aus Score + aktuellem NotationProfile erzeugt; der Export verwendet exakt dieselben Daten.
- Änderungen an der Darstellungsquantisierung aktualisieren die Vorschau automatisch nach kurzer Verzögerung.
- Native Bedienelemente: Seite zurück/vor, Seitenanzeige, Zoom −/+, Aktualisieren.
- Rendering erfolgt in der App mit Verovio im eingebetteten WKWebView.
- Für die erste Fassung wird das offizielle Verovio-Webmodul über HTTPS geladen; dafür ist eine Internetverbindung erforderlich.
- MIDI und interner Score werden durch die Vorschau niemals verändert.
- MusicXML-Export bleibt ausschließlich auf der Notensatz-Seite.
- Engine Build 14 unverändert.

V4.9.4 – Triolische Darstellungsquantisierung
- Einsatz-/Positionsquantisierung ergänzt um „Achteltriolen“ und „16teltriolen“.
- Triolische Raster werden als 1/3- bzw. 1/6-Beat-Raster behandelt.
- Passende triolische Noten- und Pausenwerte erhalten im MusicXML eine echte 3:2-time-modification.
- Unterstützt werden halbe, Viertel-, Achtel-, 16tel- und 32tel-Triolenwerte.
- Binäre Raster bleiben unverändert; 1/3-Werte werden dort nicht automatisch verwendet.
- Vorschau und Export verwenden weiterhin dasselbe NotationProfile.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.4.1 – Vorschaufehler behoben
- Fehlerhafte maskierte Swift-Interpolation in MusicXMLPreviewView korrigiert.
- Base64-MusicXML, Seitenzahl und Zoom werden jetzt tatsächlich an JavaScript übergeben.
- Fehlermeldungen zeigen nun den echten WebKit-/JavaScript-Fehlertext.
- Zoomanzeige und Seitenanzeige zeigen reale Werte statt \(...)-Text.
- Die bisherigen Compiler-Warnungen zu unbenutztem base64/error entfallen dadurch.
- Triolische Darstellungsquantisierung aus V4.9.4 unverändert.

V4.9.5 – Notenquantisierung / kleinster Notenwert
- Neue Darstellungsoption „Kleinster Notenwert“.
- Auswahl: Aus, Viertel, Achtel, 16tel, 32tel, 64tel.
- Die Einstellung betrifft ausschließlich die notierte Darstellung in Vorschau und MusicXML.
- Kürzere Notendauern werden notatorisch mindestens auf den gewählten Wert angehoben.
- Bei der Teilung an Zählzeiten werden keine zusätzlichen Fragmente unterhalb des gewählten Mindestwerts erzeugt, soweit dies innerhalb eines Taktes vermeidbar ist.
- MIDI und interner Score bleiben unverändert.
- Bestehende gespeicherte NotationProfiles bleiben kompatibel; ohne neuen Wert ist die Notenquantisierung „Aus“.
- Triolische Einsatzquantisierung aus V4.9.4 bleibt unverändert.
- Engine Build 14 unverändert.

V4.9.6 – Darstellungsquantisierung nach dem Cubase-Prinzip
- Die bisherigen separaten Felder für Einsatzraster und einen einzigen Mindestnotenwert
  wurden durch drei musikalisch klarere Einstellungen ersetzt:
  1. Rhythmusmodus: Auto / Gerade / Triolisch
  2. Kleinster gerader Notenwert
  3. Kleinster triolischer Notenwert
- Auto prüft für jede Einsatzposition sowohl das gerade als auch das triolische Raster
  und verwendet den näheren Rasterpunkt.
- Gerade unterdrückt triolische Notenwerte; Triolisch unterdrückt gerade Notenwerte.
- Gerade und triolische Mindestwerte werden getrennt behandelt.
- Die Notenbildvorschau aktualisiert sich wie bisher unmittelbar.
- Pausenglättung, Notenlängenglättung, Taktanfang und Zählzeitenteilung bleiben
  als Feinabstimmung erhalten.
- Alte gespeicherte NotationProfiles aus V4.9.5 und früher werden weiterhin gelesen.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.6.1 – Compile-Fix
- Fehlende Hilfsfunktion isTripletGrid nach der Umstellung auf das Cubase-artige
  Rhythmusmodell wieder ergänzt.
- Rein triolischer Modus wird damit beim Teilen von Notenwerten korrekt erkannt.
- Auto-Modus bleibt gemischt: gerade und triolische Werte dürfen nebeneinander vorkommen.
- Keine funktionalen Änderungen an MIDI, Score oder Vorschau.
- Engine Build 14 unverändert.

V4.9.6.2 – Balkengruppierung
- Achtel und kürzere Werte erhalten echte MusicXML-Balkeninformationen.
- Balkengruppen werden konservativ innerhalb einer Viertelzählzeit gebildet.
- Achtel werden typischerweise paarweise, 16tel zu Vierergruppen gebalkt.
- Pausen, Unterbrechungen und Zählzeitgrenzen trennen Balken.
- 16tel und kürzere Werte erhalten zusätzlich einen zweiten Balken.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.6.3 – Bassschlüssel für linke Klavierhand
- Getrennte Klavierspuren mit Namen wie „Piano – Linke Hand“ / „Left Hand“
  werden bei einstimmigem System automatisch im Bassschlüssel notiert.
- Bei unbenannten Klavierspuren dient zusätzlich die mittlere Tonlage als
  konservative Erkennung für ein tiefes Bass-System.
- Rechte-Hand-/hohe Klavierspuren bleiben im Violinschlüssel.
- Mehrsystemige Parts verwenden weiterhin oben G- und unten F-Schlüssel.
- Balkengruppierung aus V4.9.6.2 bleibt unverändert.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.7 – MIDI-Player mit Nachklang und stabilerer Ausgabe
- Interne Wiedergabe erhält eine reine Player-Kopie des MIDI mit 1,2 Sekunden Nachklang.
  Dadurch wird der Synthesizer nach dem letzten Note-Off nicht sofort abgeschnitten.
- Exportierte MIDI-Dateien und der interne Score bleiben unverändert.
- Auch externe MIDI-Wiedergabe wartet 1,2 Sekunden nach dem letzten Ereignis,
  bevor All Notes Off gesendet und die Wiedergabe beendet wird.
- Der externe MIDI-Timer läuft nun im Common RunLoop Mode mit kürzerem Intervall
  und kleiner Toleranz. Dadurch sollen UI-Aktionen weniger Timing-Aussetzer/Hüpfer verursachen.
- Stop/Pause bleiben bewusst sofort wirksam.
- Engine Build 14 unverändert.

V4.9.7.1 – Vorschlagsnoten und technische Pausen
- Fehler behoben: semantische Notationsereignisse wurden nach Darstellungsquantisierung
  teils nicht mehr der ursprünglichen Note zugeordnet, weil sourceStart versehentlich
  auf die verschobene Notationsposition gesetzt wurde.
- Explizite Acciaccatura/Appoggiatura-Ereignisse aus dem internen Score werden dadurch
  wieder zuverlässig als echte Vorschlagsnoten erkannt.
- Automatisch erzeugte Pausen in sekundären MusicXML-Stimmen werden nun unsichtbar
  ausgegeben (print-object="no"). Sie bleiben für die Stimmenzeitrechnung erhalten,
  erscheinen aber nicht mehr als störende technische Pausen im Notenbild.
- Pausen der Hauptstimme bleiben sichtbar.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.7.2 – Vorschlagsnote vor Takt 4 korrigiert
- Ursache präzisiert: XNote hatte bislang nur die bereits darstellungsquantisierte
  Startposition. Dadurch wurde die ursprüngliche Score-Position 11.875 der
  Acciaccatura C6 schon vor der Fragmentbildung zu 12.0 und das semantische
  orn/acciaccatura-Ereignis konnte nicht mehr gefunden werden.
- XNote führt nun zusätzlich sourceStart mit der unveränderten Originalposition.
- Fragment/eventMatchesNote verwendet ausschließlich sourceStart für die Zuordnung
  semantischer Notationsereignisse.
- Die Acciaccatura bei Beat 11.875 / Pitch 84 in „Schneeaschemosaik“ kann dadurch
  trotz Darstellungsquantisierung korrekt erkannt und vor Takt 4 notiert werden.
- Unsichtbare technische Nebenstimmen-Pausen aus V4.9.7.1 bleiben erhalten.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.7.3 – Überflüssige technische Pausen wirklich ausblenden
- Korrektur der MusicXML-Syntax: print-object="no" gehört auf das <note>-Element,
  nicht auf <rest>.
- Verovio konnte die bisherige Schreibweise deshalb ignorieren und die technischen
  Nebenstimmen-Pausen weiterhin anzeigen.
- Sekundärstimmen behalten ihre Pausen rechnerisch, aber sie werden jetzt tatsächlich
  unsichtbar dargestellt.
- Echte Pausen der Hauptstimme bleiben sichtbar.
- Vorschlagsnoten-Korrektur aus V4.9.7.2 bleibt enthalten.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V4.9.7.4 – Tempoangaben im Notenbild bereinigt
- Die Anfangs-Metronomangabe wird nur noch einmal, im ersten Part, ausgegeben.
- ritardando / rallentando / accelerando / stringendo erscheinen als Text ohne
  zusätzliche sichtbare BPM-Zahl.
- a tempo / tempo primo erscheinen ebenfalls ohne wiederholte Metronomzahl.
- Numerische Zieltempi bleiben bei solchen Ausdrucksangaben als unsichtbare
  MusicXML-<sound tempo>-Information erhalten.
- Eine sichtbare Metronomzahl wird nur noch bei einer echten neuen Tempo-Festlegung
  ausgegeben.
- MIDI und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V5.0 – Drucken aus der Notenbildvorschau
- Neuer Button „Drucken …“ direkt in der Werkzeugleiste der Notenbildvorschau.
- Vor dem Drucken werden automatisch alle Verovio-Partiturseiten gerendert.
- macOS-Druckdialog wird geöffnet; damit sind normaler Drucker und „Als PDF sichern“
  unmittelbar verfügbar.
- Drucklayout: A4 Hochformat mit Seitenumbrüchen zwischen den Partiturseiten.
- Nach Schließen des Druckdialogs kehrt die Vorschau automatisch auf die zuvor
  angezeigte Seite und den normalen Vorschauzustand zurück.
- MusicXML-Export, MIDI und interner Score bleiben unverändert.
- Notensatzverbesserungen aus V4.9.7.4 vollständig enthalten.
- Engine Build 14 unverändert.

V5.0.1 – Druckausgabe korrigiert
- Der direkte Druck des WKWebView wurde verworfen, weil macOS dabei in diesem Aufbau
  leere Seiten ausgeben konnte.
- Neuer Druckweg: alle Verovio-Seiten rendern -> WebKit erzeugt daraus ein PDF ->
  PDFKit übergibt dieses PDF an den normalen macOS-Druckdialog.
- Dadurch wird genau das bereits sichtbare Notenbild gedruckt.
- A4/Seitenskalierung erfolgt im PDF-Druckdialog; „Als PDF sichern“ bleibt verfügbar.
- Nach dem Drucken wird die vorherige Vorschauseite wiederhergestellt.
- Notensatz und MusicXML-Erzeugung bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.2 – Notensatz-Layout und persistenter Vorschau-Zoom
- Werkzeugleiste der Notenbildvorschau neu angeordnet: Seiten-, Zoom-, Aktualisieren-
  und Druckfelder stehen kompakt links und werden nicht mehr an den rechten Rand gequetscht.
- Darstellungsregeln und Export stehen untereinander statt in einer gequetschten Horizontalzeile.
- Exportbutton erhält eine stabile Mindestbreite.
- Maus-/Trackpad-Zoom benutzt jetzt die native WKWebView-Vergrößerung.
- Der aktuelle Zoom bleibt beim automatischen Neurendern, Seitenwechsel und Aktualisieren erhalten.
- +/- und Maus-/Trackpad-Zoom verwenden denselben Zoomwert.
- Zoombereich 50–200 %.
- Druckfunktion aus V5.0.1 unverändert enthalten.
- MIDI, MusicXML und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.3 – Notensatz-Trenner bleibt stehen / längerer MIDI-Nachklang
- Ursache des scheinbaren Zoomfehlers korrigiert: Beim Ziehen des linken Randes
  der Notenbildvorschau wurde tatsächlich der NSSplitView-Trenner bewegt.
  Harte Mindestbreiten der linken Notensatzspalte zwangen ihn beim Loslassen zurück.
- Die linke Spalte darf jetzt deutlich schmaler werden; ihre harten 318-Punkt-
  Breiten wurden gelockert.
- Der Notensatz-SplitView speichert seine Dividerposition dauerhaft über autosaveName.
- Die vom Nutzer eingestellte Breite der Notenbildvorschau bleibt dadurch nach
  dem Loslassen und auch nach erneutem Öffnen der App erhalten.
- MIDI-Player-Nachklang von 1,2 auf 3,0 Sekunden verlängert.
- Gilt für interne und externe MIDI-Wiedergabe.
- Exportierte MIDI-Dateien und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.4 – Druck: eine Partiturseite pro Papierseite
- Druckpipeline erneut korrigiert: nicht mehr alle Verovio-Seiten in ein einziges
  langes WebKit-PDF rendern.
- Stattdessen wird jede Verovio-Partiturseite einzeln als PDF erzeugt.
- Die einzelnen PDF-Seiten werden mit PDFKit zu einem mehrseitigen Dokument zusammengefügt.
- Ergebnis: Seite 1 der Partitur = Seite 1 des Drucks, Seite 2 = Seite 2 usw.
- Der macOS-Druckdialog skaliert jede Partiturseite passend auf genau eine Papierseite.
- Drucker und „Als PDF sichern“ bleiben unverändert verfügbar.
- Nach dem Drucken kehrt die Vorschau auf die zuvor angezeigte Seite zurück.
- MIDI, MusicXML und interner Score bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.5 – IAC-Bus / externe MIDI-Ausgabe gepuffert
- Ursache des Stolperns adressiert: Externe MIDI-Ereignisse wurden bislang einzeln
  aus einem Main-Thread-Timer ohne CoreMIDI-Zeitstempel gesendet.
- Neuer rollender CoreMIDI-Puffer mit ca. 180 ms Look-ahead.
- Note-On, Note-Off, Controller und Program Change werden mit echten
  MIDITimeStamp-Werten an IAC/virtuelle MIDI-Ziele übergeben.
- Der Main-Thread-Timer füllt nur noch alle 25 ms den Puffer nach; das musikalische
  Timing übernimmt CoreMIDI selbst.
- UI-Aktionen, Scrollen und kurzfristige Main-Thread-Last sollten die Wiedergabe
  dadurch nicht mehr hörbar ins Stolpern bringen.
- Stop/Pause/Seek bleiben unmittelbar wirksam; 3,0 Sekunden Nachklang bleiben erhalten.
- Interne AVMIDIPlayer-Wiedergabe und exportierte MIDI-Dateien bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.5.1 – Compile-Fix für CoreMIDI-Zeitstempel
- MIDIGetCurrentHostTime und MIDIConvertNanosToHostTime waren auf dem verwendeten
  macOS-SDK nicht verfügbar.
- Host-Zeit wird nun portabel über mach_absolute_time() und mach_timebase_info()
  aus Darwin berechnet.
- Das 180-ms-Look-ahead-Puffern und die CoreMIDI-MIDITimeStamp-Ausgabe bleiben
  funktional unverändert.
- Keine Änderung an MIDI-Daten, Score oder Notensatz.
- Engine Build 14 unverändert.

V5.0.6 – IAC-Ausgabe vollständig auf Apple MusicPlayer umgestellt
- Die eigene Timer-/Look-ahead-Wiedergabe für externe MIDI-Ziele wurde entfernt.
- Composition Lab erzeugt für die Wiedergabe eine komplette MIDI-Sequenz und übergibt
  sie an Apples AudioToolbox MusicSequence/MusicPlayer.
- Der ausgewählte IAC-Bus wird mit MusicSequenceSetMIDIEndpoint direkt als Ziel gesetzt.
- Note-On, Note-Off, Controller, Pedal und Program Change werden dadurch vom
  Core-Audio-MIDI-Scheduler abgespielt, nicht mehr vom Main Thread der App.
- Ein Timer bleibt nur zur Anzeige des Wiedergabeendes; er steuert keine Noten mehr.
- 3,0 Sekunden Nachklang bleiben erhalten.
- Interne AVMIDIPlayer-Wiedergabe und exportierte MIDI-Dateien bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.7 – Verovio-Fußzeile entfernt / sauberer weißer Druck
- Verovio-Fußzeile/Logo wird über die offizielle Renderer-Option footer="none" deaktiviert.
- Für die PDF-/Druckerzeugung wird ein eigener Print-Clean-Modus aktiviert.
- Grauer WebView-Hintergrund, Seitenrahmen und Schatten werden beim Drucken vollständig entfernt.
- Die Druckseite bleibt weiß; nur die eigentliche Partitur wird ausgegeben.
- Nach dem Drucken kehrt die Vorschau automatisch in ihren normalen Bildschirmmodus zurück.
- IAC/MusicPlayer-Änderungen aus V5.0.6 bleiben unverändert.
- Engine Build 14 unverändert.

V5.0.8 – Notensatz-Divider springt nicht mehr zurück
- Die harten Mindest-/Maximalbreiten der linken Notensatzspalte wurden vollständig entfernt.
- Linke Einstellungsleiste und ihre Controls dürfen horizontal komprimiert werden.
- Nur noch eine sehr weiche 90-Punkt-Mindestbreite mit niedriger Priorität bleibt als Griffbereich.
- NSSplitView-Holding-Prioritäten wurden so gesetzt, dass die vom Nutzer gewählte Dividerposition
  nicht durch Auto Layout wieder aufgedrückt wird.
- Die vorhandene NSSplitView-Autosave-Einstellung bleibt erhalten.
- Verovio-/Druckkorrekturen aus V5.0.7 und MusicPlayer-IAC-Ausgabe aus V5.0.6 bleiben enthalten.
- Engine Build 14 unverändert.

V5.0.9 – Notenbild von Anfang an groß
- Der verschiebbare SplitView auf der Notensatz-Seite wurde entfernt.
- Linke Parameterleiste jetzt fest 300 Punkte breit.
- Die Notenbildvorschau nutzt automatisch den gesamten verbleibenden Platz.
- Kein Divider mehr, der beim Loslassen zurückspringen kann.
- Schmale Trennlinie bleibt rein optisch erhalten.
- Druck-, Verovio- und IAC-Änderungen der Vorversionen bleiben enthalten.
- Engine Build 14 unverändert.

V5.0.10 – Notenbild nutzt wirklich den ganzen rechten Bereich
- Fehler der V5.0.9 behoben: Die horizontale NSStackView ließ die rechte Vorschau
  nur auf ihre Inhaltsbreite wachsen und erzeugte rechts großen Leerraum.
- Die Notensatz-Seite verwendet jetzt direkte Auto-Layout-Constraints.
- Linke Parameterleiste fest 300 Punkte breit.
- Rechte Notenbildfläche ist direkt an den rechten Fensterrand geheftet.
- Die Vorschau erhält automatisch die komplette verbleibende Breite.
- Kein verschiebbarer Divider.
- Druck-, Verovio- und IAC-Änderungen der Vorversionen bleiben enthalten.
- Engine Build 14 unverändert.

V5.0.11 – Fenstergröße und Position zuverlässig speichern
- Hauptfenster speichert Größe und Position explizit in UserDefaults.
- Speicherung erfolgt bei Größenänderung, Verschieben, Schließen und App-Beenden.
- Beim nächsten Start wird exakt dieser Fensterrahmen wiederhergestellt.
- Falls der gespeicherte Bildschirm nicht mehr verfügbar ist, wird das Fenster
  automatisch in den sichtbaren Bereich eines vorhandenen Bildschirms verschoben.
- Die bisherige alleinige NSWindow-Autosave-Lösung wurde entfernt.
- Notensatz-, Druck-, Verovio- und IAC-Änderungen der Vorversionen bleiben enthalten.
- Engine Build 14 unverändert.
