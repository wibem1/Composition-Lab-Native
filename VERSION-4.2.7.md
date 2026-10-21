# Composition Lab Native 4.2.7 — lokale Testfassung, 21.10.2026

Gezielte Windows-Reparatur für den lokalen LilyPond-Start. Die unnötige sofortige
Suche nach installierten Windows-Anwendungen wird aus GIOs DLL-Initialisierung
entfernt. Der LilyPond-Compiler und Guile bleiben die offiziellen 2.24.4-Dateien.
Nur GIO derselben Version 2.72.4 sowie dessen zlib-Abhängigkeit werden eingesetzt;
Prüfsummen, vollständige Export-Schnittstelle und importierte Funktionen werden
vor dem Paketbau geprüft. Quellcode, Patch und Lizenz liegen dem Paket bei.

Zusätzlich gelten Abbruch und Zeitlimit auch für offene Ausgabekanäle; Teilprotokolle
bleiben erhalten. Die Statusanzeige zeigt verständliche Notensatzschritte statt
langer Bibliothekswarnungen. Der Notensatz arbeitet vollständig lokal.

Diese Vorabversion wird erst nach gemeinsamen Kernprüfungen, nativen Mac- und
Windows-Tests sowie vollständigem Selbsttest des entpackten Windows-ZIPs erstellt.
Sie ist noch keine auf dem betroffenen Windows-PC bestätigte Reparatur: Der dortige
122-Sekunden-Startfehler ließ sich auf den Build-Rechnern bislang nicht reproduzieren.
Die GIO-Warnungen der Diagnose liefern einen Ansatz, aber keinen Kausalitätsbeweis.
Die bisherige reguläre Version wird deshalb nicht ersetzt.
