# Maßgebliche GUI: Composition Lab Mac 3.5.3

Quelle: `wibem1/Composition-Lab-Native`, `main`, Commit `a2aefd72c53878019058bdc6f6a2ffec2c4615dc`.

`Sources/MainViewController.swift` und `Sources/PieceSlotDropButton.swift` sind die Referenz. Die Windows-Builder in `MacGui.cs` spiegeln deren bestehende Builder. Kein neuer Seitenentwurf.

| Mac-Builder | Windows-Builder | Vorgabe |
|---|---|---|
| buildUI | BuildMacUI | Kopf 52, Main / Noten / Technik, Status 28 |
| buildV64Controls | BuildMacMain: controls | KI, Modell, Denkaufwand, Takte, Taktart, Tempo, Tonart, Instrumente |
| buildV64WorkArea | BuildMacMain: work | 66/34, MusicChat mit eigener Eingabe + Senden, editierbare Kompositionsidee |
| buildV64Deck | BuildMacMain: deck | Stücke 1–10, 116×164, Abstand 8, horizontaler Scrollbereich, Menü/Dateidrop |
| buildV64BottomBar | BuildMacMain: bottom | Player, dann MIDI/CLAB/Import/Motiv/Komponieren linksbündig |
| buildMusicXMLWorkspace | BuildMacNotation | linke Spalte 300, gleiche Presets und Darstellungsparameter, Vorschau/Export rechts |
| buildTechnicalWorkspace | BuildMacTechnology | Technik, Aktionsleiste, Prüfung / JSON / Verlauf |

Die Ausführung `--capture-gui-reference OUTPUT` ist nur eine Build-Prüfung. Sie erzeugt drei Bilder und eine Liste der tatsächlichen sichtbaren Mac-Steuerelemente; normaler App-Start bleibt unverändert. Das Original auf `main` wird nicht geändert.

Windows verwendet native Windows-Steuerelemente und Segoe UI. Apple-AppKit und die Systemschrift lassen sich nicht unverändert auf Windows ausführen. Systemdialoge, Menüleisten und Schrift-Rasterung sind deshalb plattformspezifisch. Der strukturelle Aufbau folgt der Mac-Quelle. Kleine Fenster dürfen den ursprünglichen Inhalt scrollen.

Noch fehlende Plattformadapter: verschlüsselte Mac-Backups sowie Soundfont-/direkte MIDI-Ausgangswahl. Diese Menüaktionen erklären die Einschränkung statt einen falschen Erfolg zu melden. Die vollständige Mac-MusicChat-Aktionssteuerung ist noch nicht portiert; der vorhandene Windows-Chat bleibt erhalten. LilyPond/Hacklily befinden sich weiterhin im Dateimenü. Dies ist eine GUI-Portierung, noch keine vollständige Funktionsgleichheit.
