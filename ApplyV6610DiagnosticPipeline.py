from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Start the diagnostic BEFORE the first API request. This guarantees that even
# a failed/partial run can be exported and shows the exact UI state used.
anchor = '''        let prompt = basePrompt()\n        status("KI entwickelt musikalischen Impuls …", good: true)\n'''
insert = '''        let prompt = basePrompt()\n        let diagnosticConceptPrompt = ComposerPrompts.conceptPrompt(prompt) + "\\n\\nWICHTIG: Formuliere die Kompositionsidee sehr knapp: höchstens 3 kurze Sätze. Nur Charakter, zentrale musikalische Idee und grobe Entwicklung. Keine Takt-für-Takt-Beschreibung, keine ausführliche Analyse und keine Noten-für-Noten-Anweisungen. Die im Auftrag angegebene Taktzahl ist VERBINDLICH: Plane ausschließlich ein Stück genau dieser Länge. Beschreibe niemals Formteile, Takte oder eine Coda außerhalb dieser Taktzahl."\n        lastDiagnostic = [\n            "format": "composition-lab-native-diagnostic",\n            "engineBuild": ComposerPrompts.engineBuild,\n            "interface": "macOS AppKit",\n            "interfaceVersion": "6.6.10",\n            "provider": p.rawValue,\n            "model": m,\n            "reasoning": e.rawValue,\n            "stage": "concept-request",\n            "uiMeasures": measuresField.stringValue,\n            "uiMeter": meterField.stringValue,\n            "uiTempo": tempoField.stringValue,\n            "uiKey": musicalKeyField.stringValue,\n            "uiEnsemble": ensembleField.stringValue,\n            "visibleTask": chatInput.stringValue,\n            "assignment": prompt,\n            "systemPrompt": ComposerPrompts.system,\n            "conceptPrompt": diagnosticConceptPrompt\n        ]\n        status("KI entwickelt musikalischen Impuls …", good: true)\n'''
if anchor not in s:
    raise SystemExit('V6.6.10: compose prompt anchor not found')
s = s.replace(anchor, insert, 1)

# Use exactly the same string that is stored in the diagnostic.
old_call = '''                              user: ComposerPrompts.conceptPrompt(prompt) + "\\n\\nWICHTIG: Formuliere die Kompositionsidee sehr knapp: höchstens 3 kurze Sätze. Nur Charakter, zentrale musikalische Idee und grobe Entwicklung. Keine Takt-für-Takt-Beschreibung, keine ausführliche Analyse und keine Noten-für-Noten-Anweisungen. Die im Auftrag angegebene Taktzahl ist VERBINDLICH: Plane ausschließlich ein Stück genau dieser Länge. Beschreibe niemals Formteile, Takte oder eine Coda außerhalb dieser Taktzahl.",\n                              wantJSON: false) { [weak self] firstResult in\n'''
new_call = '''                              user: diagnosticConceptPrompt,\n                              wantJSON: false) { [weak self] firstResult in\n'''
if old_call not in s:
    raise SystemExit('V6.6.10: V6.6.9 concept call not found')
s = s.replace(old_call, new_call, 1)

# Record a first-stage failure instead of losing the run.
old = '''            case .failure(let error):\n                DispatchQueue.main.async { self?.status("Fehler: \\(error.localizedDescription)", good: false) }\n            case .success(let concept):\n'''
new = '''            case .failure(let error):\n                DispatchQueue.main.async {\n                    if var d = self?.lastDiagnostic {\n                        d["stage"] = "concept-failed"\n                        d["conceptError"] = error.localizedDescription\n                        self?.lastDiagnostic = d\n                    }\n                    self?.status("Fehler: \\(error.localizedDescription)", good: false)\n                }\n            case .success(let concept):\n'''
if old not in s:
    raise SystemExit('V6.6.10: first-stage failure block not found')
s = s.replace(old, new, 1)

# As soon as the concept exists, persist it. This is the critical point for the
# 8-vs-12-bars bug: we can see what Gemini actually answered before score generation.
old = '''                DispatchQueue.main.async {\n                    self?.lastConcept = concept.text\n                    self?.conceptView.string = self?.conceptDisplay(concept.text, provider: p, model: m) ?? concept.text\n                    self?.status("KI komponiert …", good: true)\n                }\n\n                let compPrompt = """\n'''
new = '''                DispatchQueue.main.async {\n                    self?.lastConcept = concept.text\n                    self?.conceptView.string = self?.conceptDisplay(concept.text, provider: p, model: m) ?? concept.text\n                    if var d = self?.lastDiagnostic {\n                        d["stage"] = "concept-response"\n                        d["conceptResponse"] = concept.text\n                        d["conceptInputTokens"] = concept.inputTokens\n                        d["conceptOutputTokens"] = concept.outputTokens\n                        self?.lastDiagnostic = d\n                    }\n                    self?.status("KI komponiert …", good: true)\n                }\n\n                let compPrompt = """\n'''
if old not in s:
    raise SystemExit('V6.6.10: concept success UI block not found')
s = s.replace(old, new, 1)

# Persist exact second-stage prompt before sending it.
anchor = '''                APIClient.shared.call(provider: p, model: m, key: key, effort: e,\n                                      system: ComposerPrompts.system, user: compPrompt, wantJSON: true) { [weak self] secondResult in\n'''
replacement = '''                DispatchQueue.main.async {\n                    if var d = self?.lastDiagnostic {\n                        d["stage"] = "score-request"\n                        d["compositionPrompt"] = compPrompt\n                        self?.lastDiagnostic = d\n                    }\n                }\n\n                APIClient.shared.call(provider: p, model: m, key: key, effort: e,\n                                      system: ComposerPrompts.system, user: compPrompt, wantJSON: true) { [weak self] secondResult in\n'''
if anchor not in s:
    raise SystemExit('V6.6.10: second API call anchor not found')
s = s.replace(anchor, replacement, 1)

# Record second-stage failure too.
old = '''                    case .failure(let error):\n                        DispatchQueue.main.async { self?.status("Fehler: \\(error.localizedDescription)", good: false) }\n                    case .success(let response):\n'''
new = '''                    case .failure(let error):\n                        DispatchQueue.main.async {\n                            if var d = self?.lastDiagnostic {\n                                d["stage"] = "score-failed"\n                                d["scoreError"] = error.localizedDescription\n                                self?.lastDiagnostic = d\n                            }\n                            self?.status("Fehler: \\(error.localizedDescription)", good: false)\n                        }\n                    case .success(let response):\n'''
if old not in s:
    raise SystemExit('V6.6.10: second-stage failure block not found')
s = s.replace(old, new, 1)

# Replace the old one-shot diagnostic assignment with an update of the already
# existing record. Include decoded score metadata so requested and actual length
# can be compared without manually reading the score JSON.
start = s.find('''                                self?.lastDiagnostic = [\n                                    "format": "composition-lab-native-diagnostic",''')
if start < 0:
    raise SystemExit('V6.6.10: old diagnostic assignment start not found')
end_marker = '''                                    "scoreResponse": response.text\n                                ]\n'''
end = s.find(end_marker, start)
if end < 0:
    raise SystemExit('V6.6.10: old diagnostic assignment end not found')
end += len(end_marker)
newdiag = '''                                if var d = self?.lastDiagnostic {\n                                    d["stage"] = "completed"\n                                    d["conceptResponse"] = concept.text\n                                    d["compositionPrompt"] = compPrompt\n                                    d["scoreResponse"] = response.text\n                                    d["decodedTitle"] = score.ti\n                                    d["decodedTempo"] = score.bpm\n                                    d["decodedMeter"] = "\\(score.ts.n)/\\(score.ts.d)"\n                                    d["decodedTrackCount"] = score.tr.count\n                                    d["totalInputTokens"] = inputTokens\n                                    d["totalOutputTokens"] = outputTokens\n                                    self?.lastDiagnostic = d\n                                }\n'''
s = s[:start] + newdiag + s[end:]

# If a legacy/restored composition has no pipeline diagnostic, still allow the
# user to save a useful snapshot instead of showing "no diagnostic".
old = '''    @objc private func saveDiagnosticPressed() {\n        guard let d=lastDiagnostic, JSONSerialization.isValidJSONObject(d), let data=try? JSONSerialization.data(withJSONObject:d,options:[.prettyPrinted,.sortedKeys]) else {\n            status("Noch keine Diagnosedatei vorhanden. Bitte zuerst komponieren.",good:false); return\n        }\n'''
new = '''    @objc private func saveDiagnosticPressed() {\n        if lastDiagnostic == nil, let score = lastScore {\n            lastDiagnostic = [\n                "format": "composition-lab-native-diagnostic",\n                "engineBuild": ComposerPrompts.engineBuild,\n                "interface": "macOS AppKit",\n                "interfaceVersion": "6.6.10",\n                "stage": "fallback-current-state",\n                "provider": (lastProvider ?? provider).rawValue,\n                "model": lastModel ?? model,\n                "uiMeasures": measuresField.stringValue,\n                "uiMeter": meterField.stringValue,\n                "uiTempo": tempoField.stringValue,\n                "uiKey": musicalKeyField.stringValue,\n                "uiEnsemble": ensembleField.stringValue,\n                "visibleTask": chatInput.stringValue,\n                "currentConcept": lastConcept,\n                "currentScore": (try? String(data: JSONEncoder.pretty.encode(score), encoding: .utf8)) ?? ""\n            ]\n        }\n        guard let d=lastDiagnostic, JSONSerialization.isValidJSONObject(d), let data=try? JSONSerialization.data(withJSONObject:d,options:[.prettyPrinted,.sortedKeys]) else {\n            status("Noch keine Diagnosedaten vorhanden.",good:false); return\n        }\n'''
if old not in s:
    raise SystemExit('V6.6.10: saveDiagnosticPressed block not found')
s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.10 persistent full-pipeline diagnostics.')
