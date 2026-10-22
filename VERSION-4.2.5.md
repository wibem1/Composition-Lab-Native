# Composition Lab Native 4.2.5 · 20.10.2026

Windows: Der LilyPond-Aufruf nutzt ausdrücklich die mitgelieferte Fontconfig-Konfiguration und einen dauerhaften beschreibbaren Schriftcache. Er übernimmt keine fremde Fontconfig-Konfiguration mehr. Die Partitur und die installierten Schriften bleiben unverändert. Der lokale Notensatz zeigt seine Verarbeitungsschritte während des Aufrufs an.

Das bisherige Zwei-Minuten-Limit bleibt unverändert. Ein Zeitlimit wird jetzt von einem Benutzerabbruch unterschieden und mit aktuellem Prozessprotokoll und Laufzeit gespeichert. Auch Fehler bei „Fertige Komposition übernehmen“ ersetzen die alte Diagnose durch einen aktuellen Bericht. Das Protokoll wird vor dem Löschen temporärer Dateien gesichert.

Tests prüfen einen echten Prozessabbruch mit erhaltenem Protokoll, expliziten Benutzerabbruch, Notensatz der unveränderten Pastorale trotz absichtlich ungültiger geerbter Fontconfig-Einstellung sowie die Wiederverwendung ihres Notensatzcaches. Der CI-Bericht enthält die gemessene kalte Notensatzdauer der Pastorale. Vollständige Tests und native Builds sind vor Veröffentlichung Pflicht.

Die Ursache der Verzögerung auf dem betroffenen Benutzerrechner ist noch nicht abschließend belegt. Diese Version beseitigt die Abhängigkeit von fremden Schrift-Einstellungen und macht den tatsächlich stockenden Verarbeitungsschritt nachvollziehbar. Sie verspricht keine bereits am Benutzerrechner gemessene Beschleunigung.
