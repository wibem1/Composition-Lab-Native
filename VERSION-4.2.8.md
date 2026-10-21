# Composition Lab Native 4.2.8 — lokaler LilyPond-Reparaturkandidat

21. Oktober 2026

## Korrekturen
- Windows-Build prüft die gepackten Guile-Quellen und Bytecode-Dateien anhand fester SHA-256-Werte und korrigiert gegebenenfalls Zeitstempel des Guile-Caches.
- Der reparierte LilyPond-Lauf muss offline MIDI und SVG erzeugen. Andernfalls wird der Windows-Build verworfen.
- Der lokale Notensatz nutzt weiterhin LilyPond 2.24.4 und den geprüften GIO-Runtime-Kandidaten; keine KI-Konvertierung der Originalnoten.
- Eigenständige Versions- und Buildnummer 4.2.8 / 4208 für Mac und Windows.

## Prüfung
GitHub Actions erstellt installierbare Mac- und Windows-Archive nur nach erfolgreich abgeschlossenen nativen Selbsttests, gemeinsamen Swift-Tests und dem Test des erneut entpackten Windows-Pakets.

Die Tests auf GitHub sind keine Zusicherung, dass das frühere Zeitlimitproblem auf jedem Windows-PC behoben ist. Die betroffene Installation muss zusätzlich praktisch getestet werden.
