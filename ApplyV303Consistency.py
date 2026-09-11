from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Composition Lab Native 3.0.3
# Consistency model:
# - the latest explicit user instruction in MusicChat may update the visible top settings
# - the editable composition idea remains authoritative musical text
# - before score generation, contradictions between idea header and visible settings
#   are never silently sent to the model; the user resolves them explicitly

# ---------------------------------------------------------------------------
# 1) MusicChat may return explicit setting updates derived from the CURRENT
#    user contribution. This is semantic model output, not local trigger logic.
# ---------------------------------------------------------------------------
old = '''        - sourceSlots enthält nur die Stücke, die nach dem Gesprächskontext tatsächlich Material für eine spätere Komposition sein sollen. Sonst [].\n        - Behaupte niemals, dass bereits eine Partitur oder ein Entwurf als Musikdatei erzeugt wurde. Das geschieht ausschließlich über den blauen Komponieren-Button.\n\n        Antworte ausschließlich als JSON:\n        {\n          "reply":"natürliche, knappe Dialogantwort",\n          "compositionAssignment": null ODER "knapper geklärter Kompositionsauftrag",\n          "compositionIdea": null ODER "vollständige aktuelle Kompositionsidee",\n          "sourceSlots":[1,2]\n        }\n'''
new = '''        - sourceSlots enthält nur die Stücke, die nach dem Gesprächskontext tatsächlich Material für eine spätere Komposition sein sollen. Sonst [].\n        - Wenn der AKTUELLE Nutzerbeitrag eine bisherige Vorgabe ausdrücklich ändert oder präzisiert (z.B. andere Taktzahl, anderes Tempo, andere Tonart, Taktart oder Besetzung), gib diese neu geltenden Werte zusätzlich in resolvedSettings zurück.\n        - resolvedSettings enthält NUR Werte, die sich aus dem aktuellen Nutzerbeitrag eindeutig als neue geltende Vorgabe ergeben. Erfinde dort nichts und kopiere nicht bloß unveränderte vorhandene Werte.\n        - Die compositionIdea muss bereits zu den neu geltenden Werten passen.\n        - Behaupte niemals, dass bereits eine Partitur oder ein Entwurf als Musikdatei erzeugt wurde. Das geschieht ausschließlich über den blauen Komponieren-Button.\n\n        Antworte ausschließlich als JSON:\n        {\n          "reply":"natürliche, knappe Dialogantwort",\n          "compositionAssignment": null ODER "knapper geklärter Kompositionsauftrag",\n          "compositionIdea": null ODER "vollständige aktuelle Kompositionsidee",\n          "sourceSlots":[1,2],\n          "resolvedSettings": {\n            "measures": null ODER "16",\n            "meter": null ODER "3/4",\n            "tempo": null ODER "84",\n            "key": null ODER "G-Dur",\n            "ensemble": null ODER "Klavier"\n          }\n        }\n'''
if old not in s:
    raise SystemExit('V3.0.3: MusicChat JSON contract anchor not found')
s = s.replace(old, new, 1)

old = '''                    let sourceSlots = (object["sourceSlots"] as? [Any] ?? []).compactMap { value -> Int? in\n                        if let n = value as? Int { return n }\n                        if let n = value as? NSNumber { return n.intValue }\n                        return nil\n                    }.filter { $0 >= 1 && $0 <= 10 }\n\n                    DispatchQueue.main.async {\n'''
new = '''                    let sourceSlots = (object["sourceSlots"] as? [Any] ?? []).compactMap { value -> Int? in\n                        if let n = value as? Int { return n }\n                        if let n = value as? NSNumber { return n.intValue }\n                        return nil\n                    }.filter { $0 >= 1 && $0 <= 10 }\n                    let resolvedSettings = object["resolvedSettings"] as? [String: Any] ?? [:]\n                    func resolvedString(_ key: String) -> String? {\n                        let value = resolvedSettings[key]\n                        if value == nil || value is NSNull { return nil }\n                        if let x = value as? String {\n                            let t = x.trimmingCharacters(in: .whitespacesAndNewlines)\n                            return t.isEmpty ? nil : t\n                        }\n                        if let x = value as? NSNumber { return x.stringValue }\n                        return nil\n                    }\n                    let resolvedMeasures = resolvedString("measures")\n                    let resolvedMeter = resolvedString("meter")\n                    let resolvedTempo = resolvedString("tempo")\n                    let resolvedKey = resolvedString("key")\n                    let resolvedEnsemble = resolvedString("ensemble")\n\n                    DispatchQueue.main.async {\n'''
if old not in s:
    raise SystemExit('V3.0.3: MusicChat parse anchor not found')
s = s.replace(old, new, 1)

old = '''                        if let assignment, !assignment.isEmpty {\n                            self.promptView.string = assignment\n                        }\n                        if let idea, !idea.isEmpty {\n                            self.conceptView.string = idea\n                            self.lastConcept = idea\n                        }\n'''
new = '''                        // The newest explicit natural-language instruction wins and is\n                        // made visible immediately in the top controls. This keeps the UI,\n                        // assignment and idea in one coherent state.\n                        if let x = resolvedMeasures { self.measuresField.stringValue = x }\n                        if let x = resolvedMeter { self.meterField.stringValue = x }\n                        if let x = resolvedTempo { self.tempoField.stringValue = x }\n                        if let x = resolvedKey { self.musicalKeyField.stringValue = x }\n                        if let x = resolvedEnsemble { self.ensembleField.stringValue = x }\n\n                        if let assignment, !assignment.isEmpty {\n                            self.promptView.string = assignment\n                        }\n                        if let idea, !idea.isEmpty {\n                            self.conceptView.string = idea\n                            self.lastConcept = idea\n                        }\n'''
if old not in s:
    raise SystemExit('V3.0.3: MusicChat UI update anchor not found')
s = s.replace(old, new, 1)

old = '''                            d["sourceSlots"] = sourceSlots\n                            if let assignment, !assignment.isEmpty { d["compositionAssignment"] = assignment }\n'''
new = '''                            d["sourceSlots"] = sourceSlots\n                            d["resolvedSettings"] = resolvedSettings\n                            if let assignment, !assignment.isEmpty { d["compositionAssignment"] = assignment }\n'''
if old not in s:
    raise SystemExit('V3.0.3: dialogue diagnostic anchor not found')
s = s.replace(old, new, 1)

# ---------------------------------------------------------------------------
# 2) Compose preflight: detect a standard idea header and resolve conflicts.
#    No silent precedence between manually edited idea and visible settings.
# ---------------------------------------------------------------------------
old = '''        let p = provider\n        let m = model\n        let e = effort\n        let assignment = basePrompt()\n        let visibleIdea = conceptView.string.trimmingCharacters(in: .whitespacesAndNewlines)\n\n        // No idea yet: create the musical idea only. This deliberate stop is what\n'''
new = r'''        let p = provider
        let m = model
        let e = effort
        var visibleIdea = conceptView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Composition Lab 3.0 ideas normally start with:
        // Takte · Taktart · Tempo BPM · Tonart · Besetzung
        // If the user edited that header manually, never let contradictory values
        // leak into the score prompt unnoticed.
        func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "–", with: "-")
        }
        func parseIdeaFrame(_ text: String) -> (measures:String, meter:String, tempo:String, key:String, ensemble:String)? {
            guard let first = text.split(separator: "\n", omittingEmptySubsequences: true).first else { return nil }
            let parts = first.split(separator: "·").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count >= 5 else { return nil }
            let measures = parts[0].replacingOccurrences(of: "Takte", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
            let meter = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let tempo = parts[2].replacingOccurrences(of: "BPM", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let ensemble = parts[4...].joined(separator: " · ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !measures.isEmpty, !meter.isEmpty, !tempo.isEmpty, !key.isEmpty, !ensemble.isEmpty else { return nil }
            return (measures, meter, tempo, key, ensemble)
        }
        func currentFrameHeader() -> String {
            let bars = measuresField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let meter = meterField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let tempo = tempoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = musicalKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let ensemble = ensembleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(bars.isEmpty ? "frei" : bars) Takte · \(meter.isEmpty ? "frei" : meter) · \(tempo.isEmpty ? "frei" : tempo) BPM · \(key.isEmpty ? "frei" : key) · \(ensemble.isEmpty ? "frei" : ensemble)"
        }

        if !visibleIdea.isEmpty, let frame = parseIdeaFrame(visibleIdea) {
            var conflicts: [String] = []
            let uiMeasures = measuresField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let uiMeter = meterField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let uiTempo = tempoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let uiKey = musicalKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let uiEnsemble = ensembleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !uiMeasures.isEmpty && normalized(uiMeasures) != normalized(frame.measures) { conflicts.append("Takte: oben \(uiMeasures), Idee \(frame.measures)") }
            if !uiMeter.isEmpty && normalized(uiMeter) != normalized(frame.meter) { conflicts.append("Taktart: oben \(uiMeter), Idee \(frame.meter)") }
            if !uiTempo.isEmpty && normalized(uiTempo) != normalized(frame.tempo) { conflicts.append("Tempo: oben \(uiTempo) BPM, Idee \(frame.tempo) BPM") }
            if !uiKey.isEmpty && normalized(uiKey) != normalized(frame.key) { conflicts.append("Tonart: oben \(uiKey), Idee \(frame.key)") }
            if !uiEnsemble.isEmpty && normalized(uiEnsemble) != normalized(frame.ensemble) { conflicts.append("Besetzung: oben \(uiEnsemble), Idee \(frame.ensemble)") }

            if !conflicts.isEmpty {
                let alert = NSAlert()
                alert.messageText = "Kompositionsidee und Vorgaben widersprechen sich"
                alert.informativeText = conflicts.joined(separator: "\n") + "\n\nWelche Werte sollen für die Komposition gelten?"
                alert.addButton(withTitle: "Kompositionsidee übernehmen")
                alert.addButton(withTitle: "Obere Vorgaben verwenden")
                alert.addButton(withTitle: "Abbrechen")
                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    measuresField.stringValue = frame.measures
                    meterField.stringValue = frame.meter
                    tempoField.stringValue = frame.tempo
                    musicalKeyField.stringValue = frame.key
                    ensembleField.stringValue = frame.ensemble
                    saveSettingsFromUI()
                case .alertSecondButtonReturn:
                    let lines = visibleIdea.components(separatedBy: .newlines)
                    var replaced = false
                    var output: [String] = []
                    for line in lines {
                        if !replaced && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            output.append(currentFrameHeader())
                            replaced = true
                        } else {
                            output.append(line)
                        }
                    }
                    visibleIdea = output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    conceptView.string = visibleIdea
                    lastConcept = visibleIdea
                default:
                    status("Komposition wegen widersprüchlicher Vorgaben abgebrochen.", good: false)
                    return
                }
            }
        }

        let assignment = basePrompt()

        // No idea yet: create the musical idea only. This deliberate stop is what
'''
if old not in s:
    raise SystemExit('V3.0.3: compose preflight anchor not found')
s = s.replace(old, new, 1)

# Diagnostics version.
s = s.replace('"interfaceVersion": "3.0.2"', '"interfaceVersion": "3.0.3"')
s = s.replace('"interfaceVersion": "3.0.1"', '"interfaceVersion": "3.0.3"')
s = s.replace('"interfaceVersion": "3.0.0"', '"interfaceVersion": "3.0.3"')

p.write_text(s, encoding='utf-8')
print('Applied V3.0.3: semantic setting updates and explicit conflict resolution before composition.')
