# Music Lab System – EV Contract

Stand: 8. September 2026
Status: verbindliche Ereignisspezifikation für `track.ev`

## 1. Zweck

`ev` enthält musikalische Notations- und Ausdrucksereignisse, die weder reine Noten (`nt`) noch MIDI-Controller (`ct`) noch rohe MIDI-Ereignisse (`me`) sind.

Ziel ist ein gemeinsamer Vertrag für Composition Lab Native, Composition Lab WebApp, Music Chat Lab und spätere DAW-/MusicXML-Adapter.

## 2. Grundform

Jedes Ereignis ist ein Objekt mit mindestens:

```json
{
  "b": 0.0,
  "t": "dynamic"
}
```

- `b`: Beatposition in Viertelnoten-Beats
- `t`: Ereignistyp
- weitere Felder hängen vom Typ ab

Unbekannte `ev`-Typen sollen bei Projekt-Roundtrips erhalten bleiben, auch wenn eine App sie nicht selbst darstellt oder auswertet.

## 3. Verbindliche Ereignistypen

### 3.1 Dynamik

```json
{"b":0,"t":"dynamic","v":"p"}
```

`v`: z. B. `ppp`, `pp`, `p`, `mp`, `mf`, `f`, `ff`, `fff`, `sfz`, `fp`

### 3.2 Dynamikverlauf / Hairpin

```json
{"b":4,"t":"wedge","v":"crescendo","id":"w1"}
{"b":8,"t":"wedge-stop","id":"w1"}
```

`v`: `crescendo` oder `diminuendo`

### 3.3 Pedal

```json
{"b":0,"t":"pedal","v":"start"}
{"b":4,"t":"pedal","v":"stop"}
```

Optional zulässig: `change`, falls ein Importformat dies eindeutig liefert.

### 3.4 Artikulation

```json
{"b":2,"t":"articulation","v":"staccato"}
```

Verbindliche Werte:
- `staccato`
- `staccatissimo`
- `tenuto`
- `accent`
- `strong-accent`
- `detached-legato`

### 3.5 Ornament

```json
{"b":6,"t":"ornament","v":"trill-mark"}
```

Verbindliche Werte:
- `trill-mark`
- `turn`
- `inverted-turn`
- `mordent`
- `inverted-mordent`

### 3.6 Slur

```json
{"b":0,"t":"slur","v":"start","id":"s1"}
{"b":4,"t":"slur","v":"stop","id":"s1"}
```

`id` verbindet Start und Ende.

### 3.7 Tie

Ein musikalischer Tie kann zusätzlich zur normalen Notendauer erhalten werden, wenn die Notationsherkunft relevant ist:

```json
{"b":3,"t":"tie","v":"start","id":"t1"}
{"b":4,"t":"tie","v":"stop","id":"t1"}
```

Für reine MIDI-Wiedergabe bleibt `nt` maßgeblich.

### 3.8 Grace Note

```json
{"b":7.5,"t":"grace","v":"acciaccatura"}
```

Verbindliche Werte:
- `grace`
- `acciaccatura`
- `appoggiatura`

Die zugehörige Tonhöhe bleibt grundsätzlich in `nt`; `ev` beschreibt hier die Notationsfunktion.

### 3.9 Fermate

```json
{"b":12,"t":"fermata"}
```

Optional `v`: `normal`, `angled`, `square`.

### 3.10 Atemzeichen / Caesura

```json
{"b":15,"t":"breath"}
```

oder

```json
{"b":15,"t":"caesura"}
```

### 3.11 Text / Spielanweisung

```json
{"b":8,"t":"text","v":"dolce"}
```

Für freie musikalische Spielanweisungen, sofern kein spezieller Ereignistyp existiert.

### 3.12 Rehearsal Mark

```json
{"b":16,"t":"rehearsal","v":"A"}
```

### 3.13 Arpeggio

```json
{"b":4,"t":"arpeggio","v":"normal"}
```

Optional `v`: `normal`, `up`, `down`, `non-arpeggiate`.

## 4. Was nicht in `ev` gehört

### `nt`
Noten selbst:
- Start
- Dauer
- Pitch
- Velocity
- Staff
- Gate

### `ct`
Normale MIDI-Controller, z. B. Sustain CC64, Modulation CC1, Expression CC11.

Wenn dieselbe musikalische Information sowohl als Notationsereignis als auch als Controller vorliegt, dürfen beide Formen koexistieren, sofern sie unterschiedliche Zwecke erfüllen. Beispiel: MusicXML-Pedalzeichen in `ev`, tatsächlicher CC64-Verlauf in `ct`.

### `me`
Rohe MIDI-/DAW-Ereignisse, insbesondere solche, die möglichst unverändert transportiert werden sollen:
- Pitch Bend
- Channel Pressure / Aftertouch
- Poly Aftertouch
- SysEx
- spezielle Metaevents
- DAW-spezifische Zusatzdaten

## 5. Roundtrip-Regel

Apps dürfen unbekannte `ev`-Einträge nicht ohne Not löschen.

Eine App darf:
- bekannte Typen interpretieren
- bekannte Typen exportieren
- unbekannte Typen ignorieren

Sie soll unbekannte Typen bei CLAB-/Score-Roundtrips trotzdem erhalten.

## 6. MusicXML

MusicXML ist die wichtigste externe Quelle und Senke für `ev`.

Der Native-MusicXML-Export verwendet bereits einen großen Teil dieser Ereignisklassen. Der Import soll schrittweise auf denselben Vertrag erweitert werden.

Reihenfolge für den Importausbau:
1. `dynamic`
2. `articulation`
3. `pedal`
4. `slur`
5. `wedge` / `wedge-stop`
6. `ornament`
7. `grace`
8. weitere Typen

## 7. Versionierung

Diese Spezifikation ist `EV Contract 1`.

Neue Ereignistypen dürfen ergänzt werden, ohne bestehende Typen umzudeuten. Änderungen an der Bedeutung bestehender Typen benötigen eine neue Contract-Version.
