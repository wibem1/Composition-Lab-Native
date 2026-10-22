# Composition Lab Native 4.2.2

Die gemeinsame native Kompositionsanfrage verlangt jetzt ausdrücklich eine vollständige, eigenständig kompilierbare LilyPond-Partitur (2.24-kompatibel, alle Instrumente, Layout und MIDI). Der musikalische Auftrag bleibt unverändert am Anfang der Anfrage. Die Formatvorgabe gilt für Gemini, Anthropic und OpenAI auf Mac und Windows. Normale Chat-Anfragen und bereits lokal lesbare Notation bleiben unverändert.

Die Diagnose trennt den ursprünglichen Auftrag, die tatsächlich gesendete Anfrage, das angeforderte Ausgabeformat und das erkannte Antwortformat. Eine trotzdem gelieferte ABC-Antwort bleibt vollständig gesichert und wird als nicht lokal lesbar gekennzeichnet; sie löst keinen automatischen weiteren KI-Aufruf aus.

Regressionstests durchlaufen den tatsächlich verwendeten gemeinsamen Anfrageweg mit einem kontrollierten Modelltransport: Formatvorgabe für alle drei Anbieter, unveränderter Auftrag, exakte Diagnose, Antwort bis zur lokalen LilyPond-Vorbereitung, abweichende ABC-Antwort ohne Folgeanfrage und gewöhnlicher Chat ohne Formatvorgabe. Die bestehende native Testmatrix prüft zusätzlich echten LilyPond-Notensatz, MIDI, Originalquelle und getrennte Oberflächen auf Mac und Windows.

Freigabe erst nach allen 49 gemeinsamen Tests je Plattform und beiden nativen Builds samt Oberflächentests. Die Modellantworten werden offline simuliert; es wurde kein bezahlter Live-Aufruf mit einem Benutzer-Schlüssel durchgeführt. Die Formatvorgabe garantiert keine musikalische Qualität und kann vom Modell missachtet werden; solche Antworten bleiben zur Diagnose erhalten. Frühere Referenzversionen bleiben unverändert. Weitere Einschränkungen siehe VERSION-4.2.md.
