# Composition Lab Native 4.2.1

Korrektur der Auftragsübergabe auf Mac und Windows. Fertiger LilyPond-Notentext (auch mit Einleitung und Codeblock) wird beim Komponieren lokal übernommen. Besetzungs-, Tempo- und andere Eingabefelder verändern diese Übernahme nicht. Dafür ist kein API-Schlüssel erforderlich; es entstehen keine KI-Kosten. Fehlerhafter Notentext bleibt zur Wiederherstellung gesichert, ohne automatische KI-Anfrage.

Für eine musikalische Bearbeitung wird ein zusätzlicher Auftrag im Chatfeld eingegeben. Die gemeinsame Auftragslogik übergibt dann den vorhandenen Notentext als Arbeitsmaterial. Neue Kompositionsaufträge und ausdrücklich gesetzte Parameter bleiben unterstützt. Das Windows-Besetzungsfeld startet ohne automatische Klavier-Vorgabe; gespeicherte Eingaben bleiben erhalten.

Die Mac-Notenansicht verwirft beim Stückwechsel außerdem die alte SVG-Vorschau, bevor der neue Notensatz asynchron geladen wird. Windows bewahrt den Nachweis ohne KI-Aufruf auch in der abschließenden Notensatzdiagnose.

Regression: gemeinsame Tests für direkte Übernahme trotz alter Klavier-Einstellung sowie explizite Bearbeitung mit erhaltenem Quelltext. Beide nativen Selbsttests betätigen den echten Komponieren-Ablauf mit einer dreisystemigen Violin-/Klavierpartitur, leerem API-Schlüssel und widersprechender Besetzung. Notenzahl, Originaltext und Diagnose ohne KI-Aufruf werden geprüft; Windows prüft zusätzlich den Schutz des vorhandenen Stücks.

Veröffentlichung erst nach erfolgreicher Linux-/Mac-/Windows-Testmatrix und beiden nativen Builds samt Selbsttests. Version 4.2.0 und main bleiben als Referenzen erhalten. Bestehende Einschränkungen aus VERSION-4.2.md gelten weiter (unter anderem Mac ohne Notarisierung, vereinfachtes MusicXML, keine hörbare MIDI-Hardwareprüfung im Windows-Runner).
