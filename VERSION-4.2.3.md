# Composition Lab Native 4.2.3 · 20.10.2026

Die vollständige Pastorale für Violine und Violoncello wurde in 4.2.2 vor dem Notensatz zurückgewiesen: Die gemeinsame Quellprüfung blockierte auch die reine Dauerangabe `#(ly:make-moment 1/16)` für Notenabstände. Sie akzeptiert jetzt diesen Konstruktor ausschließlich mit positiven ganzzahligen Nennern und numerischen Literalen (Bruch oder zwei Argumente). Verschachtelte Aufrufe, zusätzliche Argumente und sonstige Scheme-Ausdrücke bleiben gesperrt. Der Originaltext bleibt unverändert; keine zusätzliche KI-Anfrage.

Die unveränderte Pastorale aus der Diagnose ist als Regressionstest enthalten. Gemeinsame Tests prüfen die Quellannahme und negative Fälle; der native Windows-Test setzt genau diese Partitur mit dem gebündelten LilyPond und prüft SVG und MIDI. Der bereits im Branch enthaltene Statusfix entfernt nach Abschluss „KI arbeitet“ und bewahrt Fehlermeldungen.

Die zweite Diagnose ist ein abgeschlossener MusicChat-Aufruf, der bewusst keine Partitur erzeugt. Senden bleibt Gespräch; „Mit gewählter KI komponieren“ erzeugt die Partitur.

Freigabe erfolgt erst nach erfolgreicher automatischer Testmatrix und beiden nativen Builds. Kein bezahlter Live-KI-Aufruf. Frühere Einschränkungen siehe VERSION-4.2.md.
