# Music Lab System – EV Contract

Stand: 8. September 2026
Status: verbindliche Ereignisspezifikation für `track.ev`
Version: EV Contract 1.1

## 1. Zweck

`ev` enthält musikalische Notations- und Ausdrucksereignisse, die weder reine Noten (`nt`) noch MIDI-Controller (`ct`) noch rohe MIDI-Ereignisse (`me`) sind.

Ziel ist ein gemeinsamer Vertrag für Composition Lab Native, Composition Lab WebApp, Music Chat Lab und spätere DAW-/MusicXML-Adapter.

## 2. Grundform

Jedes Ereignis ist ein Objekt mit mindestens:

```json
{"b":0.0,"t":"dyn"}
```

- `b`: Beatposition in Viertelnoten-Beats
- `t`: kanonischer Ereignistyp
- `v`: optionaler Wert
- `e`: optionaler Endbeat für Bereichsereignisse
- `st`: optionaler Staff
- `p`: optionaler MIDI-Pitch zur Bindung an eine konkrete Note
- `n`: optionaler Zusatzwert

Unbekannte `ev`-Typen sollen bei Projekt-Roundtrips erhalten bleiben, auch wenn eine App sie nicht selbst darstellt oder auswertet.

## 3. Kanonische Ereignistypen

Die kanonischen Typnamen richten sich nach dem bereits produktiv verwendeten Native-V5.0.11-Modell und dem vorhandenen MusicXML-Builder. Langformen wie `dynamic`, `articulation` oder `ornament` sind keine konkurrierenden Typnamen.

### 3.1 Dynamik – `dyn`

```json
{"b":0,"t":"dyn","v":"p"}
```

`v`: z. B. `ppp`, `pp`, `p`, `mp`, `mf`, `f`, `ff`, `fff`, `sfz`, `fp`.

### 3.2 Dynamikverlauf – `wedge`

```json
{"b":4,"t":"wedge","v":"crescendo","e":8}
```

`v`: `crescendo` oder `diminuendo`; `e` ist der Endbeat. Es gibt keinen separaten kanonischen `wedge-stop`-Eintrag.

### 3.3 Pedal – `pedal`

```json
{"b":0,"t":"pedal","v":"start"}
{"b":4,"t":"pedal","v":"stop"}
```

Optional zulässig: `change`.

### 3.4 Artikulation – `art`

```json
{"b":2,"t":"art","v":"staccato","p":64}
```

Aktuell vom Native-MusicXML-Pfad unterstützt:
- `staccato`
- `tenuto`
- `accent`
- `marcato`
- `fermata`

Weitere Werte dürfen ergänzt werden, ohne den Typnamen `art` zu ändern.

### 3.5 Ornament / Vorschlagsfunktion – `orn`

```json
{"b":6,"t":"orn","v":"trill"}
```

Der vorhandene Native-Builder verwendet `orn` insbesondere für `trill`, `acciaccatura` und `appoggiatura`.

### 3.6 Slur – `slur`

```json
{"b":0,"t":"slur","e":4,"st":1}
```

Ein Slur ist ein Bereichsereignis: `b` = Start, `e` = Ende. Start und Ende werden nicht als zwei getrennte `ev`-Einträge gespeichert.

### 3.7 Freie Spielanweisung – `words`

```json
{"b":8,"t":"words","v":"dolce"}
```

### 3.8 Tempo – `tempo`

```json
{"b":8,"t":"tempo","v":"rit."}
```

Der Score-Hauptwert `bpm` bleibt das globale Grundtempo; `tempo` in `ev` beschreibt lokale/expressive Tempoangaben.

### 3.9 Tie – `tie` (reserviert, noch nicht vollständig implementiert)

MusicXML-Notenbindungen sollen bei Bedarf zusätzlich zur `nt`-Dauer erhalten werden. Der Typ `tie` ist dafür reserviert, wird vom aktuellen MusicXML-Import aber noch nicht erzeugt.

Für reine MIDI-Wiedergabe bleibt `nt` maßgeblich.

### 3.10 Weitere zulässige Erweiterungen

Weitere semantische Typen wie Atemzeichen, Caesura, Rehearsal Marks oder Arpeggio dürfen ergänzt werden. Bestehende kanonische Typen dürfen dabei nicht umbenannt oder parallel durch Synonyme ersetzt werden.

## 4. Was nicht in `ev` gehört

### `nt`
Noten selbst: Start, Dauer, Pitch, Velocity, Staff, Gate.

### `ct`
Normale MIDI-Controller, z. B. Sustain CC64, Modulation CC1, Expression CC11.

Wenn dieselbe musikalische Information sowohl als Notationsereignis als auch als Controller vorliegt, dürfen beide Formen koexistieren, sofern sie unterschiedliche Zwecke erfüllen. Beispiel: MusicXML-Pedalzeichen in `ev`, tatsächlicher CC64-Verlauf in `ct`.

### `me`
Rohe MIDI-/DAW-Ereignisse, insbesondere Pitch Bend, Aftertouch, SysEx, spezielle Metaevents und DAW-spezifische Zusatzdaten.

## 5. Roundtrip-Regel

Apps dürfen unbekannte `ev`-Einträge nicht ohne Not löschen.

Eine App darf bekannte Typen interpretieren und unbekannte Typen ignorieren. Bei CLAB-/Score-Roundtrips sollen unbekannte Einträge trotzdem erhalten bleiben.

## 6. MusicXML

MusicXML ist die wichtigste externe Quelle und Senke für `ev`.

Der Native-MusicXML-Import unterstützt inzwischen:
1. `dyn`
2. `art`
3. `pedal`
4. `slur`
5. `wedge`

Weitere Importausbaustufen:
6. `tie`
7. `orn`
8. `words`
9. weitere Typen

## 7. Versionierung

Diese Spezifikation ist `EV Contract 1.1`.

Version 1.1 korrigiert die erste Dokumentfassung so, dass die kanonischen Typnamen exakt mit dem bereits vorhandenen Native-V5.0.11-Code übereinstimmen. Es wurden keine bestehenden produktiven Eventnamen im Code umbenannt.
