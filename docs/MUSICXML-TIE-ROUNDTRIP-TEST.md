# MusicXML Tie Roundtrip Test

Stand: 8. September 2026
Branch: `native-core-alignment`

## Ziel

Absicherung des vollständigen Tie-Pfads:

`MusicXML -> Score/ev(tie) -> MusicXML -> Score/ev(tie)`

Der Test orientiert sich am realen MuseScore-Muster, bei dem an derselben gebundenen Note sowohl `<tie>` als auch `<tied>` vorkommen.

## Import

Der Parser dedupliziert `<tie>` und `<tied>` zu genau einem internen Ereignis:

- `t = "tie"`
- `b = 0`
- `e = 2`
- `p = 60`
- `st = 1` bei explizitem zweistaffigem Eingang

## Export

Der Builder-Patch berücksichtigt explizite `tie`-Events zusätzlich zu seinen automatisch erzeugten Ties für notatorisch aufgeteilte lange Noten.

Für den Testfall werden genau erzeugt:

- 1 × `<tie type="start"/>`
- 1 × `<tie type="stop"/>`
- 1 × `<tied type="start"/>`
- 1 × `<tied type="stop"/>`

Es entstehen keine Duplikate.

## Re-Import

Nach erneutem Import entsteht wieder genau ein `tie`-Event mit:

- `b = 0`
- `e = 2`
- `p = 60`

Bei einem faktisch einstaffigen Export kann `st = 1` zu `st = nil` normalisiert werden, weil Staff 1 in MusicXML dann implizit ist. Das ist kein musikalischer Informationsverlust und entspricht der bereits dokumentierten Staff-Normalisierung in den früheren Roundtrip-Tests.

## Ergebnis

**BESTANDEN**

Die Tie-Semantik bleibt über den vollständigen MusicXML-Roundtrip erhalten.

## Implementierungsstand

- Importcode ist direkt in `Sources/MusicXMLParser.swift` im Entwicklungsbranch enthalten.
- Der Exportcode ist reproduzierbar als `patches/MusicXMLBuilder-tie-export.patch` gegen den unveränderten V5.0.11-Builder dokumentiert.
- Der Referenzbranch `reference-v5.0.11` bleibt unverändert.
